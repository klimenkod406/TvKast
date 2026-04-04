@echo off
echo Initializing Digital Signage Database...
echo.

set PGPASSWORD=postgres
set PGUSER=postgres
set PGBIN="C:\Program Files\PostgreSQL\18\bin"

echo Creating user 'digitalsignage'...
%PGBIN%\psql.exe -U postgres -c "DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'digitalsignage') THEN CREATE ROLE digitalsignage WITH LOGIN PASSWORD 'digitalsignage'; END IF; END $$;"

echo Creating database 'digitalsignage_db'...
%PGBIN%\psql.exe -U postgres -c "SELECT 'CREATE DATABASE digitalsignage_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'digitalsignage_db')\gexec"

echo Granting privileges...
%PGBIN%\psql.exe -U postgres -d digitalsignage_db -c "GRANT ALL PRIVILEGES ON DATABASE digitalsignage_db TO digitalsignage;"
%PGBIN%\psql.exe -U postgres -d digitalsignage_db -c "GRANT ALL ON SCHEMA public TO digitalsignage;"

echo.
echo Running schema initialization...
call npm run db:init

echo.
echo Database initialization complete!
pause
