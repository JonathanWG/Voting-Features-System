# Feature Voting System

Welcome to the Feature Voting System! This project consists of a Django (Python) backend and a Flutter (Dart) frontend, allowing users to propose new features and vote on their favorite ideas.

## Table of Contents

1.  [Project Overview](#1-project-overview)
2.  [Project Structure](#2-project-structure)
3.  [Prerequisites](#3-prerequisites)
4.  [Local Setup and Execution](#4-local-setup-and-execution)
    * [4.1. Backend (Django)](#41-backend-django)
    * [4.2. Frontend (Flutter)](#42-frontend-flutter)
5.  [Running Tests](#5-running-tests)
    * [5.1. Backend Tests (Django)](#51-backend-tests-django)
    * [5.2. Frontend Tests (Flutter)](#52-frontend-tests-flutter)
6.  [System Usage](#6-system-usage)
7.  [License](#7-license)

---

## 1. Project Overview

This system allows:
* **Users:** Register, log in, and manage their accounts.
* **Features:** Create new feature proposals, view all proposals.
* **Voting:** Vote on existing features and remove votes.
* **Feature Status:** Features can have different statuses (e.g., `Open`, `Under Review`, `Planned`, `Completed`).

---

## 2. Project Structure

The project is organized into a monorepo, containing both the Django backend and the Flutter frontend:


Voting Features System/
├── feature_voting_app/         # Flutter project root (Frontend)
│   ├── lib/
│   │   ├── models/             # Data model definitions (User, Feature)
│   │   ├── providers/          # State management logic (Auth, Feature)
│   │   ├── screens/            # Flutter application screens
│   │   └── services/           # API communication layer (ApiService)
│   ├── test/
│   │   ├── unit/               # Unit tests (Models, Providers)
│   │   └── widget_integration/ # Widget and integration tests (Screens, Flows)
│   ├── pubspec.yaml            # Flutter project dependencies and metadata
│   └── pub_get.sh              # Script to install Flutter dependencies
├── feature_voting_backend/     # Django project root (Backend)
│   ├── features/               # Django app for feature and voting functionalities
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── tests.py
│   │   └── views.py
│   ├── users/                  # Django app for user management and authentication
│   │   ├── admin.py
│   │   ├── models.py
│   │   ├── tests.py
│   │   ├── urls.py
│   │   ├── runserver.sh        # Script to start Django server
│   │   ├── settings.py
│   │   └── makemigrations.sh   # Script to apply database migrations
│   ├── mk_environment_voting_system.sh # Script to set up Python environment
│   └── README.md               # This file


---

## 3. Prerequisites

To set up and run this project locally, you will need the following software installed on your machine:

* **Git**: To clone the repository.
    * [Git Installation](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* **Python 3.9+**: For the Django backend.
    * [Python Installation](https://www.python.org/downloads/)
* **pip**: Python package installer (usually comes with Python).
* **venv** (or virtualenv): For Python virtual environments.
* **Docker and Docker Compose**: Recommended for managing PostgreSQL database and Redis cache.
    * [Docker Installation](https://docs.docker.com/get-docker/)
* **Flutter SDK**: For the frontend.
    * [Flutter Installation](https://flutter.dev/docs/get-started/install) (Ensure environment variables are configured).
* **A code editor** (e.g., VS Code, IntelliJ IDEA).

---

## 4. Local Setup and Execution

Follow the steps below to get the system up and running on your machine.

### 4.1. Backend (Django)

1.  **Clone the Repository:**
    Open your terminal and clone the project:
    ```bash
    git clone <YOUR_REPOSITORY_URL>
    cd "Voting Features System" # Or the root folder name of your project
    ```

2.  **Navigate to the Backend Directory:**
    ```bash
    cd feature_voting_backend
    ```

3.  **Set Up Python Environment and Dependencies:**
    Use the provided script to create a virtual environment and install dependencies.
    ```bash
    ./mk_environment_voting_system.sh
    ```
    * This script will:
        * Create a Python virtual environment (`venv`).
        * Activate the virtual environment.
        * Install dependencies from `requirements.txt`.

4.  **Set Up Database and Cache (Docker Compose):**
    This project uses PostgreSQL as the database and Redis for caching. Use Docker Compose to start them.
    Create a `docker-compose.yml` file in the root of the `feature_voting_backend` directory with the following content:

    ```yaml
    # feature_voting_backend/docker-compose.yml
    version: '3.8'

    services:
      db:
        image: postgres:13-alpine
        volumes:
          - postgres_data:/var/lib/postgresql/data/
        environment:
          - POSTGRES_DB=feature_voting_db
          - POSTGRES_USER=user
          - POSTGRES_PASSWORD=password
        ports:
          - "5432:5432" # Maps container port to your local machine

      redis:
        image: redis:6-alpine
        ports:
          - "6379:6379" # Maps container port to your local machine

    volumes:
      postgres_data:
    ```
    Now, start the Docker services:
    ```bash
    docker-compose up -d
    ```
    This will start PostgreSQL and Redis in the background.

5.  **Configure Environment Variables:**
    Create a `.env` file in the root of the `feature_voting_backend` directory and add the following variables (essential for Django to connect to the database and Redis):

    ```env
    # feature_voting_backend/.env
    DATABASE_URL=postgres://user:password@localhost:5432/feature_voting_db
    REDIS_URL=redis://localhost:6379/1
    SECRET_KEY=<YOUR_DJANGO_SECRET_KEY> # Generate a secure key, e.g., use [https://miniwebtool.com/django-secret-key-generator/](https://miniwebtool.com/django-secret-key-generator/)
    DEBUG=True
    ALLOWED_HOSTS=localhost,127.0.0.1
    ```
    Replace `<YOUR_DJANGO_SECRET_KEY>` with a strong, unique key.

6.  **Apply Database Migrations:**
    Ensure the virtual environment is activated (if you closed the terminal, run `./mk_environment_voting_system.sh` again to activate it).
    Then, run the migrations script:
    ```bash
    ./users/makemigrations.sh
    ```
    This script will:
    * Generate and apply database migrations, creating the necessary tables.

7.  **Create a Superuser (Optional, but Recommended):**
    To access the Django admin panel and manage data, create a superuser:
    ```bash
    python manage.py createsuperuser
    ```
    Follow the prompts to create a username, email, and password.

8.  **Start the Django Server:**
    Use the provided script to start the Django development server:
    ```bash
    ./users/runserver.sh
    ```
    The server will be available at `http://127.0.0.1:8000/`.

---

### 4.2. Frontend (Flutter)

1.  **Navigate to the Frontend Directory:**
    Open a **new terminal** (keeping the backend running in the first one) and navigate to the frontend folder:
    ```bash
    cd ../feature_voting_app # If you are in feature_voting_backend
    # Or: cd "Voting Features System"/feature_voting_app (if you are in the project root)
    ```

2.  **Install Flutter Dependencies:**
    Use the provided script to install all Flutter dependencies:
    ```bash
    ./pub_get.sh
    ```
    * This script will run `flutter pub get`.

3.  **Configure API Address:**
    In your Flutter project, you'll need to configure the `baseUrl` of your `ApiService` to point to your local backend.

    Open `feature_voting_app/lib/services/api_service.dart` and ensure `_baseUrl` is set to `http://10.0.2.2:8000` for Android emulators, or `http://localhost:8000` for iOS simulators and web/desktop browsers.

    ```dart
    // feature_voting_app/lib/services/api_service.dart
    // ...
    class ApiService {
      // For Android emulator (special address for host localhost)
      // static const String _baseUrl = '[http://10.0.2.2:8000](http://10.0.2.2:8000)';
      
      // For iOS simulator, Web, or Desktop
      static const String _baseUrl = 'http://localhost:8000'; 
      // ...
    }
    ```
    **Choose the correct option based on your development environment.**

4.  **Run the Flutter Application:**
    Connect a physical device, start an emulator (Android Studio), or a simulator (Xcode for iOS) and run the application:
    ```bash
    flutter run
    ```
    The application will be compiled and launched on the selected device/emulator.

---

## 5. Running Tests

This project includes a comprehensive test suite to ensure system quality and functionality.

### 5.1. Backend Tests (Django)

1.  **Navigate to the Backend Directory:**
    ```bash
    cd feature_voting_backend
    ```
2.  **Activate Virtual Environment:**
    ```bash
    source venv/bin/activate # or .venv/bin/activate depending on your python version/OS
    ```
3.  **Execute Tests:**
    ```bash
    python manage.py test
    ```
    Django unit and integration test results will be displayed in the console.

### 5.2. Frontend Tests (Flutter)

1.  **Navigate to the Frontend Directory:**
    ```bash
    cd feature_voting_app
    ```
2.  **Generate Mock Files (if first time or if mocks have changed):**
    For provider and widget tests using `mockito`, you need to generate `.mocks.dart` files.
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
3.  **Execute Tests:**
    ```bash
    flutter test
    ```
    Flutter unit and widget/integration test results will be displayed in the console.

---

## 6. System Usage

After setting up and running both the backend and frontend:

1.  **Access the Flutter Application:** Open the app on your emulator/simulator.
2.  **Register/Login:** On the initial screen, you can register a new account or log in with an existing one.
    * If you created a Django superuser, you can use it to log in.
3.  **Explore Features:** After logging in, you will see the list of features.
4.  **Create Feature:** If you are logged in, there will be a button to add new features.
5.  **Upvote/Unvote:** Click the "thumbs up" icon (`👍`) next to a feature to upvote or unvote it. The vote counter will update.





