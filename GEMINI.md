# KTB Bootcamp Chat

This project is a monorepo for a real-time chat application built with **Next.js** (Frontend) and **Spring Boot** (Backend). It includes comprehensive features like user authentication, real-time messaging, file sharing, and chat room management.

## Project Structure

*   `apps/backend`: The Spring Boot backend server.
*   `apps/frontend`: The Next.js frontend application.
*   `docker-compose.yaml`: Docker Compose file for running the entire stack (Frontend, Backend, MongoDB, Redis).
*   `apps/backend/docker-compose.o11y.yaml`: Docker Compose file for observability stack (Prometheus, Grafana).

## Architecture

*   **Frontend**: Next.js (React), Tailwind CSS, Socket.IO Client.
*   **Backend**: Spring Boot, Java 21, Netty-SocketIO, Spring Security (JWT), Spring AI (OpenAI).
*   **Database**: MongoDB (Persistence), Redis (Caching/PubSub).
*   **Infrastructure**: Docker, Docker Compose, AWS (ALB, EC2).

## Getting Started

### Prerequisites

*   Docker & Docker Compose
*   Node.js (v18+)
*   Java 21 (JDK)

### Running the Entire Stack (Frontend + Backend + DBs)

The easiest way to run the full application is using Docker Compose at the root level:

```bash
# Build and start all services
docker-compose up --build
```

This will start:
*   **Frontend**: `http://localhost:3000` (or configured domain)
*   **Backend API**: `http://localhost:5001`
*   **Socket.IO Server**: `http://localhost:5002`
*   **MongoDB**: `localhost:27017`
*   **Redis**: `localhost:6379`

### Running Backend Only (Development)

The backend directory (`apps/backend`) includes a `Makefile` for convenient commands.

1.  **Setup Environment**:
    ```bash
    cd apps/backend
    make setup-env  # Generates .env file with secure keys
    ```

2.  **Run Development Server**:
    ```bash
    make dev
    ```
    This runs the Spring Boot app with the `dev` profile.

### Running Frontend Only (Development)

1.  **Install Dependencies**:
    ```bash
    cd apps/frontend
    npm install
    ```

2.  **Setup Environment**:
    Copy `.env.example` to `.env.local` and configure API URLs.

3.  **Run Development Server**:
    ```bash
    npm run dev
    ```
    The frontend will be available at `http://localhost:3000`.

## Deployment

### Docker Hub

The frontend image can be built and pushed to Docker Hub:

```bash
# Build and Push using docker-compose-fe.yaml
docker-compose -f docker-compose-fe.yaml build
docker-compose -f docker-compose-fe.yaml push
```

### AWS Deployment (ALB + EC2)

The application is designed to be deployed on AWS EC2 instances behind an Application Load Balancer (ALB).

**Key Configurations:**
*   **ALB Listener Rules**:
    *   Path `/api/*` -> Forward to Backend Target Group (Port 5001)
    *   Path `/socket.io/*` -> Forward to Socket Target Group (Port 5002)
    *   Default -> Forward to Frontend Target Group (Port 3000)
*   **Socket.IO Stickiness**: The Socket.IO Target Group (Port 5002) **MUST** have Stickiness enabled (Load balancer generated cookie) for stable connections.
*   **Health Checks**:
    *   Backend (5001): `/api/health`
    *   Socket (5002): TCP Check (Recommended) or HTTP Check on `/socket.io/` with success codes `200-499`.
    *   Frontend (3000): `/_health` (Custom endpoint returning 200 OK)

## Troubleshooting

*   **Socket Connection Failed (400 Bad Request)**: Check if Stickiness is enabled on the ALB Target Group for port 5002.
*   **CORS Issues**: Check `SecurityConfig.java` in the backend to ensure the frontend domain is allowed.
*   **Mixed Content Error**: Ensure the frontend is built with `NEXT_PUBLIC_SOCKET_URL` starting with `https://` if the site is served over HTTPS.
