# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file and restore dependencies (cached layer)
COPY ["src/HotelBookingApi/HotelBookingApi.csproj", "src/HotelBookingApi/"]
RUN dotnet restore "src/HotelBookingApi/HotelBookingApi.csproj"

# Copy all source and build
COPY . .
WORKDIR "/src/src/HotelBookingApi"
RUN dotnet build "HotelBookingApi.csproj" -c Release -o /app/build

# ── Stage 2: Publish ──────────────────────────────────────────────────────────
FROM build AS publish
RUN dotnet publish "HotelBookingApi.csproj" -c Release -o /app/publish \
    /p:UseAppHost=false

# ── Stage 3: Runtime ──────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Create logs directory
RUN mkdir -p /app/logs

# Copy published output
COPY --from=publish /app/publish .

# Non-root user for security
RUN useradd -m appuser && chown -R appuser /app
USER appuser

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "HotelBookingApi.dll"]
