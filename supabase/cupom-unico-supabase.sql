-- =====================================================================
--  CUPOM COM VAGAS LIMITADAS · Entre Histórias
--  Rode este arquivo no Supabase: menu "SQL Editor" > cole tudo > Run.
--  Pode rodar mesmo se você já rodou a versão anterior: ele só atualiza.
--  Depois, confira que a URL do projeto e a chave "anon public" estão
--  em CONFIG.supabase dentro do checkout.html.
-- =====================================================================

-- 1) Tabela dos cupons com vagas limitadas
create table if not exists public.cupons_unicos (
  codigo   text primary key,
  usado    boolean not null default false,
  usado_em timestamptz
);

-- Novas colunas: quantas vagas o cupom tem e quantas já foram usadas
alter table public.cupons_unicos add column if not exists limite integer not null default 1;
alter table public.cupons_unicos add column if not exists usos   integer not null default 0;

-- Quem já tinha sido marcado como usado na versão anterior conta 1 uso
update public.cupons_unicos set usos = 1 where usado = true and usos = 0;

-- Ninguém mexe na tabela diretamente (só pelas duas funções abaixo)
alter table public.cupons_unicos enable row level security;

-- 2) Cadastre aqui cada cupom (em MAIÚSCULAS) e quantas pessoas podem usar
insert into public.cupons_unicos (codigo, limite) values ('7ANOSMQL', 2)
on conflict (codigo) do update set limite = excluded.limite;

-- 3) Pergunta: as vagas deste cupom já acabaram? (cupom não cadastrado conta como esgotado)
create or replace function public.cupom_ja_usado(p_codigo text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select usos >= limite from public.cupons_unicos where codigo = upper(p_codigo)),
    true
  );
$$;

-- 4) Usa uma vaga. Devolve true para quem pegou a vaga; false quando já acabaram.
create or replace function public.usar_cupom(p_codigo text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  linhas integer;
begin
  update public.cupons_unicos
     set usos     = usos + 1,
         usado    = (usos + 1 >= limite),
         usado_em = now()
   where codigo = upper(p_codigo)
     and usos < limite;
  get diagnostics linhas = row_count;
  return linhas = 1;
end;
$$;

-- 5) Libera só as duas funções para o site
revoke all on function public.cupom_ja_usado(text) from public;
revoke all on function public.usar_cupom(text) from public;
grant execute on function public.cupom_ja_usado(text) to anon, authenticated;
grant execute on function public.usar_cupom(text) to anon, authenticated;

-- =====================================================================
--  ÚTEIS
--  Ver quantas vagas já foram usadas:
--    select codigo, usos, limite from public.cupons_unicos;
--  Zerar o cupom (por exemplo, depois dos seus testes):
--    update public.cupons_unicos set usos = 0, usado = false, usado_em = null
--     where codigo = '7ANOSMQL';
--  Mudar o número de vagas:
--    update public.cupons_unicos set limite = 3 where codigo = '7ANOSMQL';
--  Cadastrar outro cupom com vagas limitadas:
--    insert into public.cupons_unicos (codigo, limite) values ('OUTROCODIGO', 5);
-- =====================================================================
