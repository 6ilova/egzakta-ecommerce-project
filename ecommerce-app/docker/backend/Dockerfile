# ============================================
# Backend Dockerfile — Spring Boot (Multi-Stage)
# ============================================
#
# WHY MULTI-STAGE:
#   The final image only contains the JRE and the compiled JAR (~150MB).
#   Without multi-stage, Maven + JDK + source would make it ~700MB.
#   Build tools are discarded after Stage 1.
#
# WHY maven:3.9-eclipse-temurin-8:
#   - The project uses Java 8 (pom.xml: <java.version>1.8</java.version>)
#   - Eclipse Temurin is the official successor to AdoptOpenJDK
#   - Maven 3.9 is the latest stable for Java 8 projects
#
# BUILD CONTEXT: Must be the project root (not this directory)
#   docker build -f docker/backend/Dockerfile .
# ============================================

# ---- Stage 1: Build ----
FROM maven:3.9-eclipse-temurin-8 AS build

WORKDIR /app

# Copy only the POM first — Docker layer caching optimization.
# Dependencies are downloaded in a separate layer, so if only source code
# changes (not dependencies), Docker reuses the cached dependency layer.
# This dramatically speeds up rebuilds.
COPY backend/spring-boot-ecommerce/pom.xml .
RUN mvn dependency:go-offline -B

# Now copy the actual source code
COPY backend/spring-boot-ecommerce/src ./src

# Build the JAR. -DskipTests because tests need a running database
# and we don't have one in the build stage.
RUN mvn clean package -DskipTests -B

# ---- Stage 2: Run ----
# WHY eclipse-temurin:8-jre-alpine:
#   - JRE-only (no JDK) — smaller image, reduced attack surface
#   - Alpine base — minimal Linux (~5MB vs ~80MB for Debian)
FROM eclipse-temurin:8-jre-alpine

WORKDIR /app

# Copy only the built JAR from Stage 1
# The JAR name comes from pom.xml: artifactId + version
COPY --from=build /app/target/spring-boot-ecommerce-0.0.1-SNAPSHOT.jar app.jar

# Document the port this service listens on
EXPOSE 8090

# Default database connection — these are overridden by docker-compose.yml
# or environment variables at runtime. Using 'db' as hostname assumes
# Docker Compose networking where the MySQL service is named 'db'.
ENV SPRING_DATASOURCE_URL=jdbc:mysql://db:3306/full-stack-ecommerce?useSSL=false&useUnicode=yes&characterEncoding=UTF-8&allowPublicKeyRetrieval=true&serverTimezone=UTC
ENV SPRING_DATASOURCE_USERNAME=ecommerceapp
ENV SPRING_DATASOURCE_PASSWORD=ecommerceapp

# WHY ENTRYPOINT vs CMD:
#   ENTRYPOINT makes the container behave like a Java executable.
#   Additional JVM flags can be passed via CMD or docker run args.
ENTRYPOINT ["java", "-jar", "app.jar"]
