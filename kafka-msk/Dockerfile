# Use an official Maven image as a parent image
FROM maven:3.8.6-openjdk-11 AS build

# Set the working directory in the container for the build stage
WORKDIR /app

# Copy the pom.xml and source code into the container
COPY pom.xml .
COPY src ./src

# Package the application into a JAR file
RUN mvn clean package -DskipTests

# Use a smaller JRE image from OpenJDK for the runtime
FROM openjdk:11-jre-slim

# Set the working directory in the container for the runtime stage
WORKDIR /app
RUN apt update && apt install curl unzip -y

# Copy the JAR file from the build stage
COPY --from=build /app/target/kafka-msk-1.0-SNAPSHOT.jar /app/kafka-msk.jar

WORKDIR /usr/local/
RUN curl -O https://download.newrelic.com/newrelic/java-agent/newrelic-agent/8.18/newrelic-java.zip
RUN unzip newrelic-java.zip
RUN rm /usr/local/newrelic/newrelic.yml
COPY newrelic/newrelic.yml /usr/local/newrelic/newrelic.yml

# Set the default command to run your application
CMD ["java", "-javaagent:/usr/local/newrelic/newrelic.jar", "-jar", "/app/kafka-msk.jar"]
# ENTRYPOINT ["tail", "-f", "/dev/null"]