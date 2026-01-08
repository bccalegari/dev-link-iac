FROM hashicorp/terraform:1.14

ARG KUBECTL_VERSION="1.35.0"

RUN apk add --no-cache bash curl jq yq git

RUN curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl