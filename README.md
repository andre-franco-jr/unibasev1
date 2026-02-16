# Unienergy Portal - App Flutter

Aplicativo mobile para monitoramento de usinas solares Unienergy com suporte para **Admin** e **Investidor**.

## 🌟 Funcionalidades

### Para Administradores (role: admin)
- ✅ Login com autenticação JWT
- ✅ Dashboard com gráficos de barras interativos
- ✅ Visualização de todas as usinas
- ✅ 3 tipos de métricas: Potência Atual, Produção Hoje, Potência Instalada
- ✅ Lista detalhada com status online/offline

### Para Investidores (role: investor)
- ✅ 4 Abas completas: Dashboard, Usinas, Documentos e DRE
- ✅ **Dashboard:**
  - Seleção de geradores com % de participação
  - Cards de resumo (Produção Total, Receita, Usinas)
  - Gráfico de geração mensal
- ✅ **Usinas:**
  - Lista de usinas vinculadas ao investidor
  - Status online/offline
  - Potência atual e produção
- ✅ **Documentos:**
  - Navegação por pastas
  - Download de arquivos
- ✅ **DRE:**
  - Demonstrativo de Resultados completo

## 📋 Pré-requisitos

- Flutter SDK 3.0.0 ou superior
- Dart SDK 3.0.0 ou superior
- Android Studio / VS Code
- Emulador Android ou iOS (ou dispositivo físico)

## 🚀 Como executar

### 1. Clone e instale as dependências

```bash
cd unienergy_app
flutter pub get
```

### 2. Execute o app

```bash
flutter run
```

## 🔐 Credenciais de Login

### Administrador
- **Usuário:** `allan`
- **Senha:** `admin`
- **Acesso:** Todas as usinas

### Investidor
- **Usuário:** `teste2`
- **Senha:** `teste2`
- **Acesso:** Geradores específicos + 4 abas

## 📱 Telas do Aplicativo

### Tela de Login
- Detecta automaticamente a role do usuário
- Redireciona para a interface correta (Admin ou Investidor)
- Credenciais pré-preenchidas para facilitar testes

### Dashboard Admin
- Cards de resumo
- Gráfico de barras com 3 métricas
- Lista de todas as usinas

### Dashboard Investidor (4 Abas)

#### 1️⃣ Dashboard
- Seletor de geradores (checkbox)
- Cards: Produção Total, Receita Estimada, Usinas
- Gráfico de barras mensal

#### 2️⃣ Usinas
- Lista de usinas do investidor
- Status online/offline
- Valores em tempo real

#### 3️⃣ Documentos
- Navegação por pastas
- Lista de arquivos
- Botão de download

#### 4️⃣ DRE
- Demonstrativo de Resultados
- Dados financeiros organizados

## 🏗️ Arquitetura

```
lib/
├── main.dart                           # Detecta role e redireciona
├── models/
│   └── usina.dart                     # Modelos: Usina, Gerador, DashboardData
├── services/
│   └── api_service.dart               # Endpoints Admin + Investidor
└── screens/
    ├── login_screen.dart              # Login com detecção de role
    ├── dashboard_screen.dart          # Dashboard Admin
    └── investor_dashboard_screen.dart # Dashboard Investidor (4 abas)
```

## 🔧 Tecnologias Utilizadas

- **Flutter** - Framework UI
- **Dio** - Cliente HTTP
- **SharedPreferences** - Armazenamento local
- **FL Chart** - Gráficos interativos
- **BottomNavigationBar** - Navegação por abas (investidor)

## 🔄 Fluxo de Autenticação

1. Usuário faz login
2. API retorna `access_token`, `refresh_token` e `role`
3. Role é salva localmente
4. App redireciona automaticamente:
   - `role: admin` → DashboardScreen
   - `role: investor` → InvestorDashboardScreen
5. Renovação automática de token a cada 1h
6. Sessão válida por 30 dias

## 📊 API Endpoints

### Admin
- `POST /api/mobile/login`
- `POST /api/mobile/refresh`
- `GET /api/mobile/usinas`
- `GET /api/mobile/usinas/{id}/desempenho`

### Investidor
- `GET /api/mobile/investor/geradores`
- `POST /api/mobile/investor/dashboard`
- `POST /api/mobile/investor/grafico`
- `GET /api/mobile/investor/usinas`
- `GET /api/mobile/investor/usinas/{id}/desempenho`
- `GET /api/mobile/investor/documentos/pastas`
- `GET /api/mobile/investor/documentos/arquivos`
- `GET /api/mobile/investor/dre`

## 🎨 Paleta de Cores

- Primary: Orange 700
- Dashboard: Orange (atual), Green (produção), Blue (instalada)
- Status: Green (online), Grey (offline)
- Cards: Blue, Green, Orange, Teal

## 📝 Notas Importantes

- O app detecta automaticamente se o usuário é Admin ou Investidor
- Investidores têm acesso a 4 abas com dados específicos
- Admins veem todas as usinas do sistema
- Todos os dados são atualizáveis via pull-to-refresh
- Conversão automática de String/Number nos JSONs da API

## 🐛 Troubleshooting

### Erro "NoSuchMethodError: toDouble"
✅ **Resolvido!** O modelo agora aceita String ou Number

### Erro de CORS (Flutter Web)
✅ **Resolvido!** Use Flutter Mobile/Desktop ou o proxy já está configurado

### Token expirado
✅ Renovação automática configurada via interceptor

## 📄 Licença

Este projeto foi desenvolvido para o Unienergy Portal.
