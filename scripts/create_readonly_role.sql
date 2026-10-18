-- Least-privilege role the agent uses to run generated SQL.
-- Can read the nine Olist tables and nothing else; cannot write, create, or alter.
-- Re-runnable. Run as postgres, then set the password separately (keeps it out of files and shell history):
--   psql -U postgres -d nl_sql_analytics -f scripts/create_readonly_role.sql
--   psql -U postgres -d nl_sql_analytics -c "\password nl_sql_readonly"

\set ON_ERROR_STOP on

-- Create the role only if it does not exist yet.
SELECT 'CREATE ROLE nl_sql_readonly'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nl_sql_readonly')
\gexec

ALTER ROLE nl_sql_readonly WITH
    LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS
    CONNECTION LIMIT 10;

-- Session defaults. Convenience guardrails only: a session can override them,
-- so the GRANTs below are the real boundary. The app also sets these per query.
ALTER ROLE nl_sql_readonly SET default_transaction_read_only = on;
ALTER ROLE nl_sql_readonly SET statement_timeout = '10s';
ALTER ROLE nl_sql_readonly SET lock_timeout = '2s';
ALTER ROLE nl_sql_readonly SET idle_in_transaction_session_timeout = '30s';

-- Database: connect only, no temporary tables.
REVOKE TEMPORARY ON DATABASE nl_sql_analytics FROM PUBLIC;
GRANT CONNECT ON DATABASE nl_sql_analytics TO nl_sql_readonly;

-- Schema: look up objects, but not create them.
GRANT USAGE ON SCHEMA public TO nl_sql_readonly;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Tables: SELECT on the Olist tables by name. Tables added to public later
-- (e.g. conversation history) are NOT readable unless granted here explicitly.
GRANT SELECT ON
    customers,
    geolocation,
    order_items,
    order_payments,
    order_reviews,
    orders,
    product_category_name_translation,
    products,
    sellers
TO nl_sql_readonly;
