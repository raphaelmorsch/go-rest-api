#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM buildpack-deps:bullseye-scm as builder

# install cgo-related dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
		pkg-config \
	; \
	rm -rf /var/lib/apt/lists/*

ENV PATH /usr/local/go/bin:$PATH

ENV GOLANG_VERSION 1.17

RUN set -eux; \
	arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
	url=; \
	case "$arch" in \
		'amd64') \
			url='https://dl.google.com/go/go1.17.linux-amd64.tar.gz'; \
			sha256='6bf89fc4f5ad763871cf7eac80a2d594492de7a818303283f1366a7f6a30372d'; \
			;; \
		'armel') \
			export GOARCH='arm' GOARM='5' GOOS='linux'; \
			;; \
		'armhf') \
			url='https://dl.google.com/go/go1.17.linux-armv6l.tar.gz'; \
			sha256='ae89d33f4e4acc222bdb04331933d5ece4ae71039812f6ccd7493cb3e8ddfb4e'; \
			;; \
		'arm64') \
			url='https://dl.google.com/go/go1.17.linux-arm64.tar.gz'; \
			sha256='01a9af009ada22122d3fcb9816049c1d21842524b38ef5d5a0e2ee4b26d7c3e7'; \
			;; \
		'i386') \
			url='https://dl.google.com/go/go1.17.linux-386.tar.gz'; \
			sha256='c19e3227a6ac6329db91d1af77bbf239ccd760a259c16e6b9c932d527ff14848'; \
			;; \
		'mips64el') \
			export GOARCH='mips64le' GOOS='linux'; \
			;; \
		'ppc64el') \
			url='https://dl.google.com/go/go1.17.linux-ppc64le.tar.gz'; \
			sha256='ee84350114d532bf15f096198c675aafae9ff091dc4cc69eb49e1817ff94dbd7'; \
			;; \
		's390x') \
			url='https://dl.google.com/go/go1.17.linux-s390x.tar.gz'; \
			sha256='a50aaecf054f393575f969a9105d5c6864dd91afc5287d772449033fbafcf7e3'; \
			;; \
		*) echo >&2 "error: unsupported architecture '$arch' (likely packaging update needed)"; exit 1 ;; \
	esac; \
	build=; \
	if [ -z "$url" ]; then \
# https://github.com/golang/go/issues/38536#issuecomment-616897960
		build=1; \
		url='https://dl.google.com/go/go1.17.src.tar.gz'; \
		sha256='3a70e5055509f347c0fb831ca07a2bf3b531068f349b14a3c652e9b5b67beb5d'; \
		echo >&2; \
		echo >&2 "warning: current architecture ($arch) does not have a compatible Go binary release; will be building from source"; \
		echo >&2; \
	fi; \
	\
	wget -O go.tgz.asc "$url.asc"; \
	wget -O go.tgz "$url" --progress=dot:giga; \
	echo "$sha256 *go.tgz" | sha256sum -c -; \
	\
# https://github.com/golang/go/issues/14739#issuecomment-324767697
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
# https://www.google.com/linuxrepositories/
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 'EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796'; \
	gpg --batch --verify go.tgz.asc go.tgz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" go.tgz.asc; \
	\
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	if [ -n "$build" ]; then \
		savedAptMark="$(apt-mark showmanual)"; \
		apt-get update; \
		apt-get install -y --no-install-recommends golang-go; \
		\
		( \
			cd /usr/local/go/src; \
# set GOROOT_BOOTSTRAP + GOHOST* such that we can build Go successfully
			export GOROOT_BOOTSTRAP="$(go env GOROOT)" GOHOSTOS="$GOOS" GOHOSTARCH="$GOARCH"; \
			./make.bash; \
		); \
		\
		apt-mark auto '.*' > /dev/null; \
		apt-mark manual $savedAptMark > /dev/null; \
		apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
		rm -rf /var/lib/apt/lists/*; \
		\
# pre-compile the standard library, just like the official binary release tarballs do
		go install std; \
# go install: -race is only supported on linux/amd64, linux/ppc64le, linux/arm64, freebsd/amd64, netbsd/amd64, darwin/amd64 and windows/amd64
#		go install -race std; \
		\
# remove a few intermediate / bootstrapping files the official binary release tarballs do not contain
		rm -rf \
			/usr/local/go/pkg/*/cmd \
			/usr/local/go/pkg/bootstrap \
			/usr/local/go/pkg/obj \
			/usr/local/go/pkg/tool/*/api \
			/usr/local/go/pkg/tool/*/go_bootstrap \
			/usr/local/go/src/cmd/dist/dist \
		; \
	fi; \
	\
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

# Create appuser
ENV USER=appuser
ENV UID=10001
# Install git + SSL ca certificates.
# Git is required for fetching the dependencies.
# Ca-certificates is required to call HTTPS endpoints.
# RUN apk update && apk add --no-cache git ca-certificates tzdata && update-ca-certificates
# See https://stackoverflow.com/a/55757473/12429735
RUN adduser \
   --disabled-password \
   --gecos "" \
   --home "/nonexistent" \
   --shell "/sbin/nologin" \
   --no-create-home \
   --uid "${UID}" \
   "${USER}"

WORKDIR $GOPATH/src/mypackage/myapp/
COPY . .
# Fix the error cannot find package "golang.org/x/net/html" in any of:
# default: #10 0.286  /usr/local/go/src/golang.org/x/net/html (from $GOROOT)
# default: #10 0.286  /go/src/golang.org/x/net/html (from $GOPATH)
RUN go mod vendor
RUN ls
# Build the binary
# RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /go/bin/hello main.go
# -mod vendor 
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /go/bin/hello -mod vendor Main.go


############################
# STEP 2 build a small image
############################
FROM scratch
# Import from builder.
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy our static executable
COPY --from=builder /go/bin/hello /go/bin/hello

# Use an unprivileged user.
USER appuser:appuser

# Run the hello binary.
ENTRYPOINT ["/go/bin/hello"]

# Run the outyet command by default when the container starts.
# ENTRYPOINT /go/bin/outyet
# Document that the service listens on port 12080.
EXPOSE 12080