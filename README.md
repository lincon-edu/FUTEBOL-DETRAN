# FUTEBOL-DETRAN — fila manual, rotação parcial e consulta pública

## Alterações
- Leitura pública do estado sem autenticação.
- Corrigida a inicialização para não renderizar jogadores antes de carregar o estado público.
- Sessão Supabase Auth persistente em F5, com storageKey estável.
- Fila sem regra de corte às 19h30.
- Setas administrativas para subir/descer jogadores na fila; ordem persistida em `queueOrder`.
- A fila exibe a quantidade de partidas disputadas.
- Após cada partida, o vencedor permanece e o perdedor é renovado parcialmente conforme a quantidade disponível na fila.
- Saem primeiro os jogadores do time perdedor com maior número de partidas; quem jogou menos tem preferência para permanecer.
- Empates na quantidade de partidas são resolvidos aleatoriamente.
- Goleiro só é substituído por goleiro; se não houver goleiro disponível, a posição permanece ocupada pelo goleiro atual.
- Jogadores que saem do time perdedor retornam ao fim da fila.
- Se a fila estiver vazia, os times permanecem como estão.

## Instalação
1. Substitua o `index.html`.
2. Execute `FUTEBOL-DETRAN-SUPABASE.sql` no SQL Editor do Supabase.
3. O SQL reaplica privilégios públicos de leitura e não apaga dados da linha `futebol_estado`.
4. Mantenha o cadastro público de usuários desabilitado em Supabase Auth; crie administradores manualmente em Authentication → Users.

## Persistência
O estado de jogadores, fila, partida, placar, cronômetro e histórico continua na linha `public.futebol_estado`. O SQL não executa `TRUNCATE`, `DELETE` nem reinicializa o JSONB existente. Escrita continua protegida pela RPC `futebol_salvar_estado`, que exige sessão autenticada.

## Regra de rotação
Exemplo: Time B perde e há quatro jogadores de linha na fila. Quatro jogadores do Time B saem e retornam ao final da fila; os quatro primeiros da fila entram. Entre os seis jogadores de linha que perderam, saem primeiro os que têm mais partidas registradas. Empates são sorteados. O goleiro é tratado separadamente.


## Atualização visual da fila, goleiro e histórico

- A descrição da fila foi simplificada para "Próximos jogadores a entrar em campo", sem instruções de administração e sem referência a 19h30.
- A lista de jogadores agora possui o botão 🧤 ao lado da lixeira. O botão alterna o atributo de goleiro do jogador; a mudança é salva no estado do Supabase e vale imediatamente para as regras de substituição.
- A aba Histórico ganhou pódio visual para os três primeiros colocados, ranking completo com barras proporcionais de gols e rolagem vertical própria.
- O histórico de partidas ganhou cartões visuais e rolagem vertical própria. As duas áreas rolam independentemente, sem alongar a página inteira.


## Configurações das regras do jogo

Após entrar como administrador, use o ícone de engrenagem ao lado de **Sair** para configurar:
- duração de cada partida;
- quantidade de jogadores por time (incluindo um goleiro);
- gols necessários para vencer por placar;
- vitórias consecutivas antes da saída simultânea dos dois times;
- modo **FriendlyFut**, que distribui os principais artilheiros entre os times.

As configurações são gravadas no mesmo estado JSONB já utilizado pela aplicação. Não é necessário alterar a estrutura do banco de dados nem executar novamente o SQL. As novas regras são compartilhadas via Supabase Realtime.


### Pênaltis no primeiro jogo

A opção **Pênaltis no primeiro jogo** habilita a disputa somente quando a primeira partida termina empatada por tempo. A tela apresenta o placar dos pênaltis, a vez de cobrança e a seleção do jogador que converteu cada gol. Cobranças sem gol avançam a alternância sem atribuição de artilheiro. São três cobranças por equipe e, em caso de empate, segue a morte súbita. O histórico registra a decisão como **Vitória nos pênaltis**, com o placar e os autores dos gols nas cobranças.

Quando a opção está desativada, um empate por tempo na primeira partida é registrado como empate e os dois times permanecem para a partida seguinte.


## Melhorias recentes — experiência mobile e decisão de empate

- A tela da partida em celulares apresenta os times em cartões verticais, com jogadores e controles de administração dimensionados para toque.
- O botão de gol abre uma confirmação com nome do jogador e time. O placar só é alterado após a confirmação.
- A regra de pênaltis foi generalizada para qualquer partida: em empate no tempo, uma sequência de vitórias maior decide o resultado; se as sequências forem iguais, a configuração de pênaltis define a disputa.
- Se não houver vantagem de sequência e os pênaltis estiverem desativados, a partida entra em morte súbita (gol de ouro): o próximo gol encerra o jogo.
- O FriendlyFut mostra apenas “Ativado” ou “Desativado”. Os parâmetros foram ajustados para telas estreitas.
- Ao salvar uma nova duração, o cronômetro de uma próxima partida ainda não iniciada é atualizado imediatamente. Uma partida já iniciada, inclusive pausada, mantém o tempo corrente; a nova duração passa a valer na próxima partida.
- A leitura da configuração antiga `penaltiesFirstMatch` é mantida como compatibilidade; a nova configuração é persistida em `penaltiesOnDraw`.


## Regra adicional — renovação simultânea condicionada à fila

- O limite de vitórias consecutivas continua definindo quando os dois times podem ser renovados simultaneamente.
- Essa renovação só ocorre quando a fila contém jogadores de linha suficientes para preencher as duas equipes: `2 × (jogadores por time - 1)`.
- Os goleiros que já estão em campo são preservados nas respectivas equipes e não entram na contagem de jogadores necessários na fila.
- Exemplo com 7 jogadores por equipe: são necessários 12 jogadores de linha na fila (6 para cada time). Com apenas 11, o time vencedor permanece em campo, mesmo que tenha ultrapassado o limite de vitórias; o time perdedor recebe as substituições possíveis pela regra normal.
- Quando a fila alcançar 12 jogadores de linha, a renovação simultânea poderá acontecer na conclusão da próxima vitória, preservando os dois goleiros atuais.
- O FriendlyFut continua sendo aplicado à distribuição dos novos jogadores de linha entre as duas equipes.

## Substituições entre times e goleiro por partida

- Durante uma partida, o administrador pode substituir um jogador de linha por alguém da fila ou trocar diretamente com um jogador de linha do outro time. Na troca entre equipes, os dois jogadores trocam de time, mantendo a quantidade de atletas em cada lado.
- Ao substituir o goleiro, o administrador pode escolher alguém da fila, um jogador de linha do próprio time ou um jogador de linha do outro time. Se a escolha vier do próprio time, o goleiro anterior passa a atuar na linha; se vier do outro time, os dois jogadores trocam de equipe.
- A função de goleiro escolhida durante a substituição é registrada em `matchGoalkeepers`, separada do cadastro permanente `goalkeeper`. Portanto, um jogador de linha pode atuar como goleiro somente naquela partida, sem alterar seu cadastro.
- Ao preparar a partida seguinte, a designação temporária é descartada e a aplicação volta a considerar os goleiros fixos cadastrados. O administrador também pode definir manualmente o goleiro da partida atual pelo botão 🧤 ao lado de cada jogador da escalação.
- O goleiro que está atualmente no outro time não aparece como opção para uma troca, evitando deixar a equipe de origem sem goleiro.
- A estrutura do banco não muda: `matchGoalkeepers` é armazenado no JSONB já existente em `public.futebol_estado`.

### Operação do goleiro na partida

A cada nova partida, a designação de goleiro é limpa para que o administrador escolha novamente quem ficará no gol. Use o botão 🧤 ao lado do jogador na escalação para defini-lo como goleiro daquela partida. Na primeira formação, os goleiros marcados no cadastro são usados como padrão. Uma designação temporária feita por substituição não altera o cadastro permanente do jogador.

## Estatísticas separadas por função (linha e goleiro)

As participações passam a ser contabilizadas separadamente conforme a função registrada no histórico de cada partida:
- **Linha:** partidas em que o jogador atuou como jogador de linha.
- **Goleiro:** partidas em que o jogador foi registrado como goleiro daquela partida, inclusive quando assumiu a posição temporariamente.
- **Gols sofridos:** soma dos gols marcados pelo adversário nas partidas em que o jogador atuou como goleiro.
- **Jogos sem sofrer gols:** partidas em que o adversário terminou com zero gol no placar normal.

O ranking e a fila exibem as quantidades de partidas na linha e no gol separadamente. O histórico já registra a função do jogador em cada partida; não é necessário alterar a estrutura do Supabase nem executar novo SQL. Registros antigos que não tenham a informação de função são considerados participações na linha, pois não há como inferir com segurança a posição exercida.


## Pré-visualização dos dois próximos times

Quando a partida em andamento puder atingir o limite configurado de vitórias consecutivas e houver jogadores de linha suficientes para formar duas equipes completas, a fila destaca os dois grupos: **Próximo Time 1** em amarelo e **Próximo Time 2** em azul. Cada grupo considera a quantidade configurada de jogadores de linha; goleiros disponíveis são identificados separadamente. Se não houver goleiro suficiente na fila, a indicação informa que o goleiro atual será mantido. A segunda equipe só aparece quando há jogadores de linha para os dois times.
