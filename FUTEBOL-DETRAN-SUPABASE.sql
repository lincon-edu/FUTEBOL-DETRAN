-- FUTEBOL-DETRAN
-- PostgreSQL / Supabase
-- Execute este script no SQL Editor do projeto Supabase.
-- O frontend utiliza somente a chave publishable/anon. NUNCA exponha service_role.

create table if not exists public.futebol_estado (
    id smallint primary key check (id = 1),
    estado jsonb not null,
    versao bigint not null default 0,
    atualizado_em timestamptz not null default now()
);

insert into public.futebol_estado (id, estado, versao)
values (
    1,
    '{
      "version": 0,
      "sessionStartedAt": null,
      "matchNumber": 0,
      "firstMatch": true,
      "players": [],
      "teams": {"A": [], "B": []},
      "score": {"A": 0, "B": 0},
      "streak": {"A": 0, "B": 0},
      "match": {
        "active": false,
        "startedAt": null,
        "remainingSeconds": 600,
        "running": false
      },
      "penalties": null,
      "history": [],
      "lastUpdatedAt": null
    }'::jsonb,
    0
)
on conflict (id) do nothing;

alter table public.futebol_estado enable row level security;

-- Leitura pública independente de sessão administrativa.
grant usage on schema public to anon, authenticated;

drop policy if exists futebol_estado_select_authenticated on public.futebol_estado;
drop policy if exists futebol_estado_select_public on public.futebol_estado;
create policy futebol_estado_select_public
on public.futebol_estado
for select
to anon, authenticated
using (true);

-- Não conceder INSERT, UPDATE ou DELETE direto ao cliente.
revoke insert, update, delete on public.futebol_estado from anon, authenticated;
grant select on public.futebol_estado to anon, authenticated;

create or replace function public.futebol_salvar_estado(
    p_estado jsonb,
    p_versao bigint
)
returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    v_versao_atual bigint;
    v_nova_versao bigint;
begin
    -- Qualquer usuário autenticado pelo Supabase Auth pode operar o painel.
    -- O projeto deve manter o cadastro público desabilitado no Supabase Auth.
    if auth.uid() is null then
        raise exception 'Autenticação obrigatória.'
            using errcode = '42501';
    end if;

    if p_estado is null or jsonb_typeof(p_estado) <> 'object' then
        raise exception 'O estado informado deve ser um objeto JSON.'
            using errcode = '22023';
    end if;

    select versao
      into v_versao_atual
      from public.futebol_estado
     where id = 1
     for update;

    if not found then
        raise exception 'Estado principal do FUTEBOL-DETRAN não inicializado.';
    end if;

    if v_versao_atual <> p_versao then
        raise exception 'Conflito de atualização: o estado foi alterado por outro usuário. Atualize a tela e tente novamente.'
            using errcode = '40001';
    end if;

    v_nova_versao := v_versao_atual + 1;

    update public.futebol_estado
       set estado = p_estado,
           versao = v_nova_versao,
           atualizado_em = now()
     where id = 1;

    return v_nova_versao;
end;
$$;

revoke all on function public.futebol_salvar_estado(jsonb, bigint) from public;
grant execute on function public.futebol_salvar_estado(jsonb, bigint) to authenticated;

-- O estado é consultável anonimamente, mas alterações só podem ocorrer via RPC
-- com sessão autenticada. Não é necessária tabela auxiliar de administradores.

-- Habilita publicação de alterações em tempo real.
do $$
begin
    if not exists (
        select 1
          from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'futebol_estado'
    ) then
        alter publication supabase_realtime add table public.futebol_estado;
    end if;
exception
    when duplicate_object then null;
end;
$$;

-- Verificação de instalação:
select
    id,
    versao,
    atualizado_em,
    jsonb_pretty(estado) as estado
from public.futebol_estado
where id = 1;


-- Reforço idempotente para instalações existentes: não apaga nem reinicializa dados.
grant usage on schema public to anon, authenticated;
grant select on public.futebol_estado to anon, authenticated;
drop policy if exists futebol_estado_select_public on public.futebol_estado;
create policy futebol_estado_select_public
on public.futebol_estado
for select
to anon, authenticated
using (true);
revoke insert, update, delete on public.futebol_estado from anon, authenticated;
