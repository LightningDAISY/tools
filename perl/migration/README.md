# Migration
create a new migration file

    $ ./migration migration [schema-name] [table-name]  

create all migration files

    $ ./migration migration [schema-name]

# Migrate
to oldest

    $ ./migration migrate 0

to newest

    $ ./migration migrate 99991231235959

# Seed
insert random 10000 records

    $ ./migration seed 10000 [schema-name] [table-name]

