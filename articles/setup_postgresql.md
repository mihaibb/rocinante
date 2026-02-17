# Setup PostgreSQL

For a rails app we need the user to be the owner of the database
- create a user with password
- create a database 
- grant all privileges on the database to the user

```sql
CREATE USER myapp_user WITH PASSWORD 'password';
CREATE DATABASE myapp_db;
GRANT ALL PRIVILEGES ON DATABASE myapp_db TO myapp_user;
```

OR

connect to the database as a superuser and run:
```bash
\c my_app_production
```

```sql
-- This transfers ownership of all tables, sequences, and functions 
-- from 'postgres' (or the old owner) to your app user.
REASSIGN OWNED BY postgres TO my_app_user;
```
