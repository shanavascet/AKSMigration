# Multi-stage Dockerfile for Spring Boot AKS deployment
FROM maven:3.9-eclipse-temurin-17 AS build

# Set working directory
WORKDIR /app

# Copy pom.xml and download dependencies (for better caching)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# Extract layers for better caching
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Production stage
FROM eclipse-temurin:17-jre-alpine

# Install curl for health checks
RUN apk --no-cache add curl

# Create non-root user
RUN addgroup -g 1001 -S spring && \
    adduser -S spring -u 1001 -G spring

# Set working directory
WORKDIR /app

# Copy dependencies from build stage
COPY --from=build /app/target/dependency/BOOT-INF/lib /app/lib
COPY --from=build /app/target/dependency/META-INF /app/META-INF
COPY --from=build /app/target/dependency/BOOT-INF/classes /app

# Change ownership to spring user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring

# Set JVM options for containers
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap"

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Entry point
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -cp /app:/app/lib/* com.yourcompany.microservices.sampleservice.SampleServiceApplication"]

# Alternative: Using Spring Boot Maven Plugin for Image Building
# You can also build images directly with Maven:
# mvn spring-boot:build-image -Dspring-boot.build-image.imageName=your-registry/sample-service:latest

# .dockerignore file contents:
# target/
# !target/*.jar
# .git
# .gitignore
# README.md
# Dockerfile
# .dockerignore
# .mvn/
# mvnw
# mvnw.cmd