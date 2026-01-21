FROM docker.io/jenkins/jenkins:2.528.3-lts-jdk21

COPY jenkins.yaml /usr/share/jenkins/ref/jenkins.yaml
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY ./jobs/jobs-backup.tar.gz /usr/share/jenkins/ref/jobs-backup.tar.gz

RUN tar -xzf /usr/share/jenkins/ref/jobs-backup.tar.gz \
    -C /usr/share/jenkins/ref && \
    rm /usr/share/jenkins/ref/jobs-backup.tar.gz

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG="/usr/share/jenkins/ref/jenkins.yaml"