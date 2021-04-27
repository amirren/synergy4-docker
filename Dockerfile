FROM openjdk:8-jdk-alpine

ARG JAR_FILE=../target/executable-netbeans/costing-calculation.jar
ARG PROP_FILE1=../target/executable-netbeans/calc.props
ARG JAR_LIB_FILE=../target/executable-netbeans/lib/

# cd /usr/local/v4calculation
WORKDIR /usr/local/v4calculation

# copy target/find-links.jar /usr/local/v4calculation/costing-calculation.jar
COPY ${JAR_FILE} costing-calculation.jar

# copy project dependencies
# cp -rf target/lib/  /usr/local/v4calculation/lib
ADD ${JAR_LIB_FILE} lib/

COPY ${PROP_FILE1} calc.props

# java -jar /usr/local/v4calculation/app.jar
ENTRYPOINT ["java","-jar","costing-calculation.jar"]