# Hotel Booking API

A secure hotel booking backend built with ASP.NET Core 8, PostgreSQL, and Auth0 JWT authentication.

> **Deployment URL:** `https://hotel-booking-api-co9y.onrender.com/`
> **Swagger UI:** `https://hotel-booking-api.onrender.com/`

---

## Architecture Overview

```
Client → Auth0 JWT Middleware → GlobalExceptionMiddleware
           → HotelsController / BookingsController
               → BookingService (conflict check, create, list)
                   → AppDbContext (PostgreSQL via EF Core)
                   → SlackNotificationService (fire-and-forget)
```

---

## Tech Stack

| Layer          | Technology                  |
|----------------|-----------------------------|
| Runtime        | .NET 8.0                    |
| Framework      | ASP.NET Core Web API        |
| Database       | PostgreSQL 16               |
| ORM            | Entity Framework Core 8     |
| Authentication | Auth0 (JWT Bearer)          |
| Logging        | Serilog                     |
| Docs           | Swagger / OpenAPI           |
| Container      | Docker + docker-compose     |
| CI/CD          | GitHub Actions              |
| Cloud          | Render.com                  |

---

## Quick Start

### Prerequisites
- .NET 8 SDK
- PostgreSQL 14+ (or Docker)
- Auth0 free account

### 1. Clone

```bash
git clone https://github.com/YOUR_USERNAME/hotel-booking-api.git
cd hotel-booking-api
```

### 2. Set up Auth0 (5 min)

1. Auth0 Dashboard → APIs → Create API
   - Identifier (Audience): `https://hotelbooking-api`
2. Create an Action (Post Login trigger) to add roles to the token:

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://hotelbooking.com/roles';
  api.accessToken.setCustomClaim(namespace, event.authorization?.roles ?? []);
};
```

3. Create roles `staff` and `reception`, assign them to test users.

### 3. Configure

Edit `src/HotelBookingApi/appsettings.Development.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=hotel_booking_dev;Username=postgres;Password=postgres"
  },
  "Auth0": {
    "Domain": "YOUR_TENANT.auth0.com",
    "Audience": "https://hotelbooking-api"
  },
  "Slack": {
    "WebhookUrl": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
  }
}
```

### 4a. Run with Docker (recommended)

```bash
cp .env.example .env   # fill in AUTH0_DOMAIN, AUTH0_AUDIENCE, SLACK_WEBHOOK_URL
docker-compose up --build
```

API: `http://localhost:8080` | Swagger: `http://localhost:8080/`

### 4b. Run without Docker

```bash
psql -U postgres -c "CREATE DATABASE hotel_booking_dev;"
cd src/HotelBookingApi
dotnet ef database update
dotnet run
```

---

## Database Scripts

All scripts are in `/scripts/init.sql`.

```bash
# Manual setup (alternative to EF migrations)
psql -U postgres -d hotel_booking -f scripts/init.sql
```

### EF Core Migrations

```bash
cd src/HotelBookingApi
dotnet ef migrations add <Name>
dotnet ef database update
```

---

## Authentication

All endpoints require:
```
Authorization: Bearer <your_access_token>
```

### Get a token (for testing)

```bash
curl --request POST \
  --url 'https://YOUR_DOMAIN.auth0.com/oauth/token' \
  --data '{
    "client_id":"YOUR_CLIENT_ID",
    "client_secret":"YOUR_CLIENT_SECRET",
    "audience":"https://hotelbooking-api",
    "grant_type":"client_credentials"
  }'
```

### Role-based access

| Endpoint                          | Required         |
|-----------------------------------|------------------|
| GET /api/hotels                   | Any auth user    |
| GET /api/hotels/{id}              | Any auth user    |
| GET /api/hotels/{id}/bookings     | Any auth user    |
| POST /api/hotels/{id}/bookings    | staff or reception |

---

## API Reference

### GET /health
No auth required.

### GET /api/hotels
Returns all hotels.

### GET /api/hotels/{hotelId}
Returns a single hotel.

### GET /api/hotels/{hotelId}/bookings

Optional query params: `startDate`, `endDate`

Example:
```
GET /api/hotels/11111111-1111-1111-1111-111111111111/bookings?startDate=2025-06-01&endDate=2025-06-30
```

Response 200:
```json
[
  {
    "id": "aaaaaaaa-...",
    "hotelId": "11111111-...",
    "guestName": "John Doe",
    "checkInDate": "2025-06-01T00:00:00Z",
    "checkOutDate": "2025-06-05T00:00:00Z",
    "createdBy": "auth0|user123",
    "createdAt": "2025-05-01T10:30:00Z"
  }
]
```

### POST /api/hotels/{hotelId}/bookings

Requires role: `staff` or `reception`

Request:
```json
{
  "guestName": "Jane Smith",
  "checkInDate": "2025-07-10",
  "checkOutDate": "2025-07-15"
}
```

Responses:
- 201 Created — booking created
- 400 Bad Request — invalid body
- 401 Unauthorized — missing/invalid token
- 403 Forbidden — wrong role
- 404 Not Found — hotel not found
- 409 Conflict — dates overlap existing booking
- 422 Unprocessable — check-in >= check-out, or check-in in the past

---

## Slack Notifications

On booking creation, support receives:
```
New Booking Created
Booking ID: ...  Hotel ID: ...  Guest: Jane Smith
Check-in: 2025-07-10  Check-out: 2025-07-15
```

Setup: create an Incoming Webhook at api.slack.com/apps and paste the URL into config.
Notification is fire-and-forget — Slack failure never blocks booking.

---

## Deployment (Render.com)

1. Push to GitHub
2. Render → New Web Service → Connect repo → set Runtime: Docker
3. Add environment variables:
   ```
   ConnectionStrings__DefaultConnection = postgres://...
   Auth0__Domain                        = your-tenant.auth0.com
   Auth0__Audience                      = https://hotelbooking-api
   Slack__WebhookUrl                    = https://hooks.slack.com/...
   ```

---

## Project Structure

```
HotelBookingApi/
├── src/HotelBookingApi/
│   ├── Controllers/
│   │   ├── BookingsController.cs      ← POST & GET booking endpoints
│   │   └── HotelsController.cs        ← GET hotel endpoints
│   ├── Data/
│   │   └── AppDbContext.cs            ← EF Core + table config + seed data
│   ├── DTOs/
│   │   └── BookingDtos.cs             ← Request/response objects
│   ├── Middleware/
│   │   ├── GlobalExceptionMiddleware.cs       ← Unified error responses
│   │   └── Auth0RoleClaimsTransformer.cs      ← Maps Auth0 roles to ClaimTypes.Role
│   ├── Models/
│   │   ├── Hotel.cs
│   │   └── Booking.cs
│   ├── Services/
│   │   ├── IBookingService.cs         ← Interface + domain exceptions
│   │   ├── BookingService.cs          ← Business logic
│   │   └── NotificationService.cs     ← Slack integration
│   ├── Program.cs                     ← DI wiring + middleware pipeline
│   ├── appsettings.json
│   └── appsettings.Development.json
├── scripts/
│   └── init.sql
├── .github/workflows/
│   └── ci-cd.yml
├── Dockerfile
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| EF Core over raw SQL | Migrations + LINQ + seed data in one place |
| Global exception middleware | Controllers stay thin; one error-format source of truth |
| Dates stored as UTC midnight | Safe cross-timezone comparisons |
| Fire-and-forget notifications | Slack failure must not fail a booking |
| INotificationService interface | Swap Slack for email in one line |
| Auto-migrate on startup | Simplifies deployment |

---

## Bonus Features

- [x] Serilog structured logging (console + rolling file)
- [x] Swagger / OpenAPI with JWT in the UI
- [x] GitHub Actions CI/CD
- [x] Docker (multi-stage Dockerfile + docker-compose)
- [x] Slack notifications on booking creation
- [x] Global error handling
- [x] Health check endpoint
