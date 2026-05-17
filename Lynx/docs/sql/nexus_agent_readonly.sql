
CREATE ROLE nexus_agent_readonly LOGIN PASSWORD 'REPLACE_ME';
GRANT CONNECT ON DATABASE current_database TO nexus_agent_readonly;
GRANT USAGE ON SCHEMA public TO nexus_agent_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO nexus_agent_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO nexus_agent_readonly;

