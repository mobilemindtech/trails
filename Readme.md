# TCL on Rails

In progress

### Features

# Configurações

* Banco de dados
* Rotas
* Filtros
* Autenticação

# Controller

* Scaffold -> 
  Os controlles devem ter ações padrão, como index, save, create, delete, edit, update, show
* Actions -> 
  Todas ações publcas devem ser identificadas como roras
* Filters ->
  Deve ser possível adicionar filtros no controller (enter, leave, recover)
* Render templates
  Deve ser possível reenderizar templates baseados em uma estrutura de pastas padrão
* Render JSON
  Deve ser possivel reenderizar um model como json

# Models

* Active record
  O model deve ter ações padrão como get, list, save, delete, update, find, find_all

# Banco de dados

* Migração de estrutura
* MySQL
* Postgres
* SQLite

# Jobs

* Baseado em cron

# Http

* Multi thread (workers)
* Websocket

# CLI

* Criação do projeto
* Criação de model
* Criação de service
* Criação de view
* Criação de controller
  
## CLI example
	- create scaffold <model name> <fields>
	- create model 	<model name> <fields>
	- create controller -model <model name>
	- create service -model <model name>
	- create views -model <model name>
