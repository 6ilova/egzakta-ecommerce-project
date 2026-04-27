# Backend Dockerfile

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Stage 1: Build 
FROM maven:3.9-eclipse-temurin-8 AS build

WORKDIR /app

# Copy only the POM first — Docker layer caching optimizati
COPY backend/spring-boot-ecommerce/pom.xml .
RUN mvn dependency:go-offline -B

# Now copy the actual source code
COPY backend/spring-boot-ecommerce/src ./src

# Build the JAR. -DskipTests because tests need a running database
RUN mvn clean package -DskipTests -B





#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Stage 2: Run
FROM eclipse-temurin:8-jre-alpine

WORKDIR /app

# Copy only the built JAR from Stage 1
COPY --from=build /app/target/spring-boot-ecommerce-0.0.1-SNAPSHOT.jar app.jar

# port this service listens on
EXPOSE 8090

# Default database connection 
ENV SPRING_DATASOURCE_URL=jdbc:mysql://db:3306/full-stack-ecommerce?useSSL=false&useUnicode=yes&characterEncoding=UTF-8&allowPublicKeyRetrieval=true&serverTimezone=UTC
ENV SPRING_DATASOURCE_USERNAME=ecommerceapp
ENV SPRING_DATASOURCE_PASSWORD=ecommerceapp


# ENTRYPOINT makes the container behave like a Java executable.
ENTRYPOINT ["java", "-jar", "app.jar"]
