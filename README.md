# 📋 Daily Tasks - App de Gerenciamento de Tarefas Diárias

Um aplicativo Flutter moderno e elegante para gerenciar suas tarefas diárias com sistema de alertas inteligentes para tarefas obrigatórias.

## ✨ Funcionalidades

### 🔔 Sistema de Alertas Inteligentes
- **Notificação no horário**: Cada tarefa dispara uma notificação no horário agendado
- **Tarefas obrigatórias**: Se marcada como obrigatória e não concluída, o alerta é reagendado automaticamente para a **próxima hora**
- **Alerta persistente**: Continua alertando a cada hora até que a tarefa seja concluída
- **Full-screen intent**: Alertas de tarefas obrigatórias aparecem mesmo com tela bloqueada

### 📱 Gerenciamento de Tarefas
- Criar, editar e excluir tarefas
- Selecionar data e horário
- Categorias: Geral, Trabalho, Pessoal, Saúde, Estudo, Finanças, Casa, Fitness
- Prioridades: Baixa, Média, Alta
- Marcar como concluída/pendente
- Adiar tarefas obrigatórias (snooze de 1h)
- Contador de vezes adiadas

### 📊 Relatórios Semanais
- Dashboard com taxa de conclusão
- Gráfico de barras por dia da semana
- Breakdown por categoria com barras de progresso
- **Envio por email** com relatório detalhado
- **Exportação PDF** para compartilhamento
- Navegação entre semanas

### 🎨 Design Moderno
- Tema escuro premium (Deep Ocean)
- Animações suaves e transições elegantes
- Seletor de data horizontal
- Cards com indicadores visuais de prioridade
- Haptic feedback em interações
- Splash screen animada
- Layout responsivo

## 🏗 Arquitetura

```
lib/
├── main.dart                    # Entry point + SplashScreen
├── models/
│   └── task_model.dart          # Modelo de dados da tarefa
├── providers/
│   └── task_provider.dart       # State management (Provider)
├── services/
│   ├── database_service.dart    # SQLite local storage
│   ├── notification_service.dart # Notificações + alertas recorrentes
│   └── report_service.dart      # Geração de relatórios + email/PDF
├── screens/
│   ├── home_screen.dart         # Tela principal + dashboard
│   ├── add_task_screen.dart     # Criar/editar tarefa
│   └── report_screen.dart       # Relatórios semanais
├── widgets/
│   ├── task_card.dart           # Card da tarefa com swipe-to-delete
│   ├── stat_widgets.dart        # Cards de estatísticas
│   └── date_selector.dart       # Seletor horizontal de data
└── utils/
    ├── app_theme.dart           # Tema e cores do app
    └── constants.dart           # Categorias e constantes
```

## 🚀 Setup

### 1. Criar projeto Flutter
```bash
flutter create daily_tasks
cd daily_tasks
```

### 2. Copiar arquivos
Substitua os arquivos do projeto pelos arquivos fornecidos:
- Copie todo o diretório `lib/` para dentro do projeto
- Substitua o `pubspec.yaml`

### 3. Instalar dependências
```bash
flutter pub get
```

### 4. Configurar Android

Substitua o arquivo `android/app/src/main/AndroidManifest.xml` pelo conteúdo do `android_manifest_example.xml`.

No `android/app/build.gradle`, atualize o `minSdkVersion`:
```gradle
defaultConfig {
    minSdkVersion 21
    // ...
}
```

### 5. Configurar iOS (opcional)

No `ios/Runner/Info.plist`, adicione:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### 6. Executar
```bash
flutter run
```

## 📦 Dependências Principais

| Pacote | Uso |
|--------|-----|
| `provider` | Gerenciamento de estado |
| `flutter_local_notifications` | Notificações e alertas |
| `sqflite` | Banco de dados local |
| `fl_chart` | Gráficos nos relatórios |
| `pdf` | Geração de relatórios PDF |
| `url_launcher` | Envio de email |
| `share_plus` | Compartilhamento de arquivos |
| `uuid` | IDs únicos para tarefas |
| `intl` | Formatação de datas em pt-BR |
| `timezone` | Suporte a fuso horário |

## 🔧 Fluxo de Tarefas Obrigatórias

```
1. Usuário cria tarefa com "Obrigatória" ativado
2. No horário agendado → Notificação com som + vibração + full-screen
3. Se NÃO concluída:
   └─→ Após 1 hora → Nova notificação (snoozeCount++)
       └─→ Após 1 hora → Nova notificação (snoozeCount++)
           └─→ Continua até ser marcada como concluída ✅
4. Quando concluída → Todas as notificações são canceladas
```

## 📧 Relatório por Email

O relatório inclui:
- Resumo: total, concluídas, pendentes, obrigatórias, taxa de conclusão
- Lista detalhada de tarefas concluídas e pendentes
- Breakdown por categoria e por dia
- Contador de vezes adiadas por tarefa
