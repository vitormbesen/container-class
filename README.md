# Guess Game com Docker Compose

Uma implantação baseada em *containers* do Jogo de Adivinhação (Flask), orquestrada com Docker Compose. A arquitetura consiste em um **database Postgres**, um backend Flask com **load balancing**, e um frontend React servido atrás de um proxy reverso NGINX.

---

## Visão Geral da Arquitetura

| Serviço | Tecnologia | Papel |
|---|---|---|
| `postgres` | Postgres 16 | *Database* com armazenamento persistente |
| `backend` | Python 3.12 + Flask | API do Jogo (3 réplicas por padrão) |
| `frontend` | NGINX + React *build* | Proxy reverso, *load balancing*, e servidor de arquivos estáticos |

---

## Estrutura do Repositório

```text
.
├── README.md
├── docker/
│   ├── backend.Dockerfile       # Imagem do backend Flask
│   └── frontend.Dockerfile      # Imagem do build React + NGINX
├── docker-compose.yaml          # Orquestração dos serviços
├── frontend/                    # Código-fonte da aplicação React
├── guess/                       # Código-fonte da lógica do jogo
├── nginx/
│   └── nginx.conf               # Configuração do NGINX (montagem via volume, facilmente substituível)
├── postgres-data/               # Dados de desenvolvimento local (ignorado pelo volume do Compose)
├── repository/                  # Camada de abstração do database (sqlite, postgres, dynamodb)
├── requirements.txt             # Dependências de produção do Python
├── requirements-dev.txt         # Dependências de desenvolvimento do Python
├── requirements-freeze.txt      
├── run.py                       # Entrypoint da aplicação Flask
├── start-backend.sh             # Script de inicialização local (não utilizado nos containers)
└── tests/                       # Suíte de testes
```

### Arquivos Principais

- **`docker/backend.Dockerfile`** — Configura o ambiente Python 3.12, instala dependências do `requirements.txt`, copia o código do jogo (`guess/`, `repository/`, `run.py`) e inicia o Flask na porta `5000`.
- **`docker/frontend.Dockerfile`** — Multi-stage *Build* : compila a aplicação React com Node 18 e, em seguida, copia o *build* estático para uma imagem NGINX Alpine.
- **`nginx/nginx.conf`** — Configuração do NGINX montada como um **volume** no *container* do frontend. Isso torna as regras de proxy e *load balancing* facilmente substituíveis sem a necessidade de um *rebuild* da imagem.
- **`docker-compose.yaml`** — Define os serviços, *networks*, *volumes*, health checks e políticas de reinício.
- **`.env`** — Variáveis de ambiente centralizadas e configuráveis pelo usuário para credenciais do *database* e configurações do backend.

---

## Pré-requisitos

- [Docker Engine](https://docs.docker.com/engine/install/) (inclui Compose v2 nas instalações modernas)
- Git

### Verifique se o Docker Compose V2 está instalado

```bash
docker compose version
```

Você deve ver uma saída semelhante a:

```text
Docker Compose version v2.27.0
```

> **Por que o Compose V2 é necessário?**
> O Compose V2 é obrigatório porque se integra nativamente à CLI do Docker, utiliza o BuildKit por padrão para **rebuilds** significativamente mais rápidos e otimizados, e fornece uma resolução de DNS interno muito superior e confiável para o **load balancing** entre as réplicas dos serviços em comparação com o antigo `docker-compose` (v1).

---

## Instalação e Primeira Execução

### 1. Clone o Repositório

```bash
git clone https://github.com/vitormbesen/container-class.git
cd container-class
```

### 2. Configure as Variáveis de Ambiente

Crie ou edite o arquivo `.env` na raiz do projeto:

```bash
# .env
DB_TYPE=postgres
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=postgres
DB_HOST=postgres
DB_PORT=5432
```

> **Nota:** O `DB_HOST` deve corresponder ao nome do serviço no Compose (`postgres`). Todas as variáveis no `.env` são automaticamente capturadas pelo Docker Compose.

### 3. Build das Imagens e Inicialização dos Serviços

```bash
# Primeiro build — compila as imagens do backend e frontend
docker compose up --build -d
```

Após o primeiro *build*, você pode iniciar o ambiente sem recompilar:

```bash
docker compose up -d
```

### 4. Acesse a Aplicação

Abra o seu navegador em:

```text
http://localhost
```

O *container* frontend NGINX escuta na porta `80` e atua como proxy roteando as chamadas de API para as instâncias do backend sob a rota `/api/`.

---

## Escalando o Backend

Para aumentar a resiliência e a capacidade de processamento, escale o serviço `backend` horizontalmente:

```bash
docker compose up -d --scale backend=3
```

O NGINX detecta automaticamente os novos IPs dos *containers* do backend através do DNS embutido do Docker (`127.0.0.11`) e distribui as requisições entre todas as instâncias saudáveis.

---

## Parando os Serviços

### Parar os *containers* (preservando os dados)

```bash
docker compose down
```

### Parar os *containers* e remover o *volume* do *database*

> **Aviso:** Isso deleta permanentemente todos os dados do jogo.

```bash
docker compose down -v
```

---

## Atualizando os Componentes

O projeto foi desenhado para facilitar atualizações através do *rebuild* das imagens com novas versões. Nenhuma alteração no código-fonte da aplicação é necessária.

### Atualizar o *Database*

Edite o `docker-compose.yaml` e mude a tag da imagem (exemplo: de `postgres:16` para `postgres:17`):

```yaml
services:
  postgres:
    image: postgres:17
```

Então faça o *rebuild* e reinicie:

```bash
docker compose up -d --build postgres
```

> **Alterações estruturais importantes:** Caso o **database** seja modificado (por exemplo, trocar por outra tecnologia de banco ou imagem com estrutura interna diferente), é estritamente necessário especificar a porta correta atualizando a variável `DB_PORT` no arquivo `.env`. Além disso, você deve ajustar o caminho de montagem do **volume** no `docker-compose.yaml` para garantir que o novo *database* persista os dados no diretório correto da nova imagem (ex: alterando `/var/lib/postgresql/data/pgdata` para o novo caminho exigido).

### Atualizar o Backend

Edite o arquivo `docker/backend.Dockerfile` e mude a imagem base:

```dockerfile
FROM python:3.13-slim   # era python:3.12-slim
```

Então faça o *rebuild*:

```bash
docker compose up -d --build backend
```

> **Acoplamento de Porta:** O projeto considera que o backend espera ser exposto na porta 5000 (definido no Dockerfile via `ENTRYPOINT` e no NGINX via `server backend:5000`). Caso você mude a porta do backend, você **deve** atualizar a porta do upstream no arquivo `nginx/nginx.conf` e recarregar o NGINX.

### Atualizar o Frontend

Edite o arquivo `docker/frontend.Dockerfile` e mude a imagem base do Node ou do NGINX:

```dockerfile
FROM node:20 AS builder        # era node:18
FROM nginx:1.32-alpine-slim    # era nginx:1.31-alpine-slim
```

Então faça o *rebuild*:

```bash
docker compose up -d --build frontend
```

### Atualizar a Configuração do NGINX

Como o arquivo `nginx/nginx.conf` é montado como um **volume** read-only (`./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro`), você pode modificar as regras do proxy ou a estratégia de *load balancing* e recarregar o serviço sem precisar de um *rebuild* da imagem:

```bash
# Edite nginx/nginx.conf, e então recarregue o NGINX
docker compose exec frontend nginx -s reload
```

---

## Decisões de Design

### Separação de Serviços

O sistema é dividido em três serviços essenciais:

- **Database (`postgres`)** — Database com persistência para Game IDs e Password. Isolado na *network* de backend.
- **Backend (`backend`)** — API Flask com business logic. Múltiplas instâncias fornecem **resiliência**; se um *container* falhar, os outros continuam servindo as requisições.
- **Frontend (`frontend`)** — Combina o SPA React e o proxy reverso NGINX em um único *container*, reduzindo a complexidade ao mesmo tempo em que mantém uma separação limpa de responsabilidades.

### Como o Backend Descobre o Database

A aplicação backend utiliza o método `from_prefixed_env()` do Flask para carregar configurações a partir de variáveis de ambiente com o prefixo `FLASK_`:

```python
def create_app(config=None):
    app = Flask(__name__)
    app.config.from_prefixed_env()   # Carrega FLASK_DB_TYPE, FLASK_DB_HOST, etc.
    ...
```

Devido à remoção automática desse prefixo no código, o `docker-compose.yaml` mapeia:

| Variável de Ambiente no Compose | Chave de Configuração no Flask | Valor proveniente do `.env` |
|---|---|---|
| `FLASK_DB_TYPE` | `DB_TYPE` | `postgres` |
| `FLASK_DB_HOST` | `DB_HOST` | `postgres` (Nome do serviço no DNS do Docker) |
| `FLASK_DB_PORT` | `DB_PORT` | `5432` |
...

O backend, portanto, descobre o endereço do *database* inteiramente através de variáveis de ambiente, sem nenhum hostname *hardcoded* no código da aplicação.

### Networks

Duas *networks* do tipo bridge foram definidas:

- **`backend-network`** — Conecta `postgres` e `backend`. O *database* não é exposto diretamente ao host local nem ao frontend.
- **`frontend-network`** — Conecta o `frontend` ao mundo externo (porta `80`). O frontend também participa da `backend-network` para conseguir alcançar os *containers* do backend.

### Volumes

- **`postgres-vol`** — Um **volume** nomeado do Docker montado em `/var/lib/postgresql/data/pgdata`. Ele sobrevive à recriação de *containers* e garante a **persistência** de todos os dados do jogo.
- **Montagem de volume de configuração** — O arquivo `nginx/nginx.conf` é injetado (*bind mount*) como read-only no *container* do frontend, permitindo alterações na configuração de rede instantaneamente sem exigir um **rebuild** completo da imagem.

### Estratégia de *Load Balancing*

O `nginx/nginx.conf` utiliza um bloco `upstream` com resolução dinâmica de DNS (em versões anteriores, isso era possível apenas com a [versão paga do NGINX](https://blog.nginx.org/blog/dynamic-dns-resolution-open-sourced-in-nginx)):

```nginx
upstream backend_servers {
    zone backend_zone 64k;
    resolver 127.0.0.11 valid=5s;
    resolver_timeout 5s;
    server backend:5000 resolve;
}
```

- **`resolver 127.0.0.11`** — Aponta para o servidor DNS interno do Docker.
- **`resolve`** — Habilita a re-resolução em background dos IPs dos *containers* (*feature* nativa de versões recentes do NGINX).
- **`server backend:5000`** — O DNS do Docker retorna todos os registros A para o serviço `backend` (um por réplica). O NGINX trata cada IP retornado como um *peer* e aplica um algoritmo de **load balancing** Round-Robin.

Essa abordagem é totalmente dinâmica: escalar o backend para cima ou para baixo **não** exige o reload do NGINX ou edições em arquivos de configuração.

### Resiliência e Políticas de Reinício

Todos os serviços declaram `restart: unless-stopped`. Se um *container* encerrar inesperadamente, o Docker o reiniciará automaticamente. Health checks estão configurados para o `postgres` e o `backend` garantindo que o `frontend` inicie apenas quando suas dependências estiverem 100% prontas. Ademais, o serviço `backend` utiliza, por padrão 2 réplicas, declaradas através de `deploy: {replicas: 2}`.

___

Este README foi gerado com assistência de LLMs.