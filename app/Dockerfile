# Build stage — Maven inside the image, so no Gradle/Maven wrapper is
# needed in the repo and the same Dockerfile works in kaniko and dind.
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build

# Dependency layer first: pom.xml rarely changes, so this layer caches.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q package -DskipTests

# Runtime stage — JRE only, non-root user.
FROM eclipse-temurin:17-jre
WORKDIR /app

RUN useradd --uid 10001 --create-home appuser
USER appuser

COPY --from=build /build/target/spring-app-*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
