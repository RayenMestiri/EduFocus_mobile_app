# 📱 EduFocus Mobile — Guide de l'Application

EduFocus Mobile est le compagnon d'apprentissage et de planification d'études conçu avec **Flutter**. L'application est entièrement connectée à l'API Node.js d'EduFocus tout en offrant un fonctionnement robuste **hors-ligne (offline-first)**.

---

## 🚀 Fonctionnalités Majeures

### 1. Packs d'Étude (Study Hub) 📦
Les **Packs d'Étude** regroupent l'ensemble du matériel pédagogique pour une matière ou un cours donné :
* **Notes** : Édition enrichie avec coloration syntaxique de code de programmation.
* **Flashcards** : Outil d'apprentissage par association de questions/réponses.
* **QCM (Quizzes)** : Questionnaires interactifs à choix multiples avec explications détaillées.
* **Fiches mémo (Cheatsheets)** : Tableaux de raccourcis ou données clés.
* **Exercices** : Questions d'entraînement avec solutions.

Chaque pack peut être publié et partagé avec la communauté via un **code de partage** (ex: `EDU-60F8BA5A...`) ou un **lien de partage** que d'autres utilisateurs peuvent directement cloner.

### 2. Algorithme de Répétition Espacée (SRS) 💡
L'apprentissage des flashcards est piloté par l'algorithme scientifique **SM-2** (SuperMemo-2), qui calcule les intervalles optimaux de révision en fonction de la difficulté rapportée par l'élève afin de maximiser la mémorisation à long terme.

### 3. Agenda d'Études Quotidien (Day Planner) 📅
Un calendrier visuel pour planifier vos heures d'études. L'interface gère les sessions d'étude en temps réel et met à jour les données en arrière-plan sans bloquer l'écran ou afficher de spinners répétitifs (mises à jour optimistes en mémoire).

### 4. Coach IA Intégré 🤖
Conseils d'études intelligents générés à la demande grâce à l'intégration de l'**API Google Gemini**, analysant vos statistiques pour vous guider.

---

## 🏗️ Architecture Technique & État

L'application utilise une architecture moderne basée sur **Riverpod 3** et des principes offline-first :

```
lib/
├── app/                  # Configuration globale (Thème, Routeur, App entrypoint)
├── core/
│   ├── config/           # Variables d'environnement (Env.apiBaseUrl, Env.frontendUrl)
│   ├── network/          # Client API HTTP (Dio configuré avec JWT Interceptor)
│   └── offline/          # Base de données locale SQLite cache, Sync Queue & Sync Engine
└── features/             # Modules organisés par domaine fonctionnel (Clean Architecture)
    ├── ai/               # Recommandations pédagogiques IA
    ├── dashboard/        # Statistiques d'études & Agenda (Day Planner)
    ├── study_hub/        # Gestion et consultation des Packs d'Étude
    └── subjects/         # Liste des Matières configurables
```

### Gestion de l'état (State Management)
L'état de l'application est géré par des contrôleurs basés sur `AsyncNotifier` (Riverpod 3) :
* Les mutations locales modifient immédiatement l'état en mémoire (`state = AsyncData([...])`) pour une réactivité instantanée à 0ms pour l'utilisateur.
* Les requêtes réseau sont exécutées en arrière-plan. En cas de déconnexion, elles sont empilées dans une **Sync Queue** locale SQLite et rejouées automatiquement dès que la connexion est rétablie.

---

## 💻 Configuration et Lancement en Développement

### 1. Variables d'environnement
Vous pouvez configurer les URL de l'API et du Frontend Web lors du build à l'aide de `--dart-define` :

* **Mode Local (Émulateur Android)** :
  ```bash
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5002 --dart-define=FRONTEND_URL=http://10.0.2.2:4200
  ```
* **Mode Local (Téléphone Physique ou Web/Desktop)** :
  ```bash
  flutter run --dart-define=API_BASE_URL=http://localhost:5002 --dart-define=FRONTEND_URL=http://localhost:4200
  ```

---

## 🔌 Débogage sur Appareil Physique Android (USB)

Lorsque vous exécutez l'application sur un smartphone Android réel connecté en USB, l'application tente d'atteindre l'API sur `127.0.0.1`. Pour que cela fonctionne avec le serveur de développement de votre ordinateur, vous devez **rediriger les ports** réseau via ADB :

```bash
# Rediriger le trafic de l'API (Backend Node.js)
adb reverse tcp:5002 tcp:5002

# Rediriger le trafic de partage (Frontend Angular)
adb reverse tcp:4200 tcp:4200
```

*(Si `adb` n'est pas configuré dans votre variable d'environnement PATH, remplacez-le par le chemin complet de l'Android SDK, par exemple `& "C:\Users\LEGION\AppData\Local\Android\Sdk\platform-tools\adb.exe"` sous Windows).*
