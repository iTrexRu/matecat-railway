FROM ubuntu:20.04

# Отключаем интерактивные запросы
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Устанавливаем базовые пакеты
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    wget \
    git \
    zip \
    unzip \
    screen \
    supervisor \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Добавляем репозитории PHP
RUN add-apt-repository ppa:ondrej/php -y \
    && add-apt-repository ppa:ondrej/apache2 -y \
    && apt-get update

# Устанавливаем все необходимые компоненты
RUN apt-get install -y \
    apache2 \
    redis-server \
    mysql-server \
    mysql-client \
    libapache2-mod-php7.4 \
    php7.4 \
    php7.4-json \
    php7.4-curl \
    php7.4-mysql \
    php7.4-xml \
    php7.4-mbstring \
    php7.4-dev \
    php7.4-redis \
    php7.4-zip \
    php7.4-gd \
    openjdk-11-jre \
    && rm -rf /var/lib/apt/lists/*

# Создаем пользователя matecat
RUN useradd --create-home --shell /bin/bash matecat

# Открываем порт
EXPOSE 80

# Копируем конфигурационные файлы
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
COPY matecat-config.ini /tmp/matecat-config.ini
COPY nodejs-config.ini /tmp/nodejs-config.ini
COPY apache-matecat.conf /tmp/apache-matecat.conf

RUN chmod +x /start.sh

# Настраиваем PHP
RUN echo "short_open_tag = On" >> /etc/php/7.4/apache2/php.ini && \
    echo "memory_limit = 1024M" >> /etc/php/7.4/apache2/php.ini && \
    echo "short_open_tag = On" >> /etc/php/7.4/cli/php.ini && \
    echo "memory_limit = 1024M" >> /etc/php/7.4/cli/php.ini

# Включаем модуль mcrypt
RUN phpenmod mcrypt || true

CMD ["/start.sh"]
