# ══════════════════════════════════════════════════════════════════════════
# Dockerfile — WebHardMon Colector
# Multi-stage build: compila con Maven → imagen runtime mínima con JRE
# ══════════════════════════════════════════════════════════════════════════

# ── Stage 1: BUILD ────────────────────────────────────────────────────────
FROM maven:3.9.6-eclipse-temurin-21 AS builder

WORKDIR /build

# Copiar solo el pom.xml primero para aprovechar la caché de capas de Docker.
# Si las dependencias no cambian, esta capa no se reconstruye.
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Copiar el código fuente y compilar el fat-jar
COPY src ./src
RUN mvn package -DskipTests -q

# ── Stage 2: RUNTIME ──────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS runtime

# Metadatos de imagen
LABEL maintainer="WebHardMon Team"
LABEL org.opencontainers.image.title="WebHardMon Colector"
LABEL org.opencontainers.image.description="Telemetry ingestion service — receives hardware metrics and forwards to Kafka"
LABEL org.opencontainers.image.version="1.0.0"

# Usuario no-root por seguridad
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copiar el fat-jar generado en el stage anterior
COPY --from=builder /build/target/colector.jar colector.jar

# Cambiar al usuario no-root
USER appuser

# Puerto del servicio REST
EXPOSE 8080

# Variables de entorno con valores por defecto (sobreescribibles en docker run / compose)
ENV SERVER_PORT=8080
ENV KAFKA_BOOTSTRAP_SERVERS=10.10.1.52:9092
ENV KAFKA_TOPIC=raw-telemetry

# Opciones de la JVM:
#   -XX:+UseContainerSupport → detecta límites de CPU/RAM del contenedor Docker
#   -XX:MaxRAMPercentage=75  → usa máximo el 75% de la RAM asignada al contenedor
#   -Djava.security.egd     → acelera el arranque en Linux sin /dev/random bloqueante
ENTRYPOINT ["java", \
            "-XX:+UseContainerSupport", \
            "-XX:MaxRAMPercentage=75.0", \
            "-Djava.security.egd=file:/dev/./urandom", \
            "-jar", "colector.jar"]
