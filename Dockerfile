# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.14
FROM ghcr.io/astral-sh/uv:python$PYTHON_VERSION-bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc python3-dev libc6-dev git curl unzip \
    && rm -rf /var/lib/apt/lists/*

# نصب bun برای ساخت فرانت‌اند داشبورد (خود ایمیج رسمی این کار را در CI انجام می‌دهد،
# ولی چون از سورس تازه کلون می‌کنیم باید اینجا خودمان انجامش دهیم)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

WORKDIR /build
RUN git clone --depth 1 https://github.com/PasarGuard/panel.git .

# ساخت خروجی استاتیک داشبورد؛ اگر این پوشه از قبل وجود نداشته باشد،
# خود برنامه هنگام استارت runtime سعی می‌کند با bun بسازدش که در ایمیج نهایی
# bun نصب نیست و باعث کرش می‌شود (FileNotFoundError: bun)
RUN cd dashboard && bun install --frozen-lockfile && cd .. && bash build_dashboard.sh

# پچ ۱: باگ فعلی برنچ main پاسارگارد -- سینتکس پایتون ۲ که در پایتون ۳ SyntaxError می‌دهد
# و باعث می‌شود کل main.py اصلاً اجرا نشود (کرش کامل هنگام استارت).
RUN sed -i 's/except ValueError, socket.gaierror:/except (ValueError, socket.gaierror):/' main.py

# پچ ۲: بدون SSL، پاسارگارد به‌صورت پیش‌فرض روی localhost گوش می‌دهد که در Railway
# باعث "Application failed to respond" می‌شود؛ این پچ همیشه 0.0.0.0 را اجباری می‌کند.
RUN sed -i 's/bind_args\["host"\] = ip/bind_args["host"] = server_settings.host/' main.py

# پچ ۳: همیشه داشبورد را mount کن (حتی وقتی DEBUG=true باشد)
COPY patches/fix-dashboard.py /tmp/fix-dashboard.py
RUN python3 /tmp/fix-dashboard.py dashboard/__init__.py && grep -A3 "run_dashboard" dashboard/__init__.py

RUN uv sync --frozen --no-dev

FROM python:$PYTHON_VERSION-slim-bookworm
COPY --from=builder /build /code
WORKDIR /code
ENV PATH="/code/.venv/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*

# نصب bun برای runtime (داشبورد هنگام استارت نیاز به bun دارد)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# نصب PasarGuard Node Agent (برای حالت ALL_IN_ONE)
RUN curl -fsSL -o /tmp/pg-node.zip https://github.com/PasarGuard/node/releases/latest/download/pasarguard-node-linux-amd64.zip \
    && unzip -o /tmp/pg-node.zip -d /tmp/pg-node \
    && mv /tmp/pg-node/pasarguard-node /usr/local/bin/pasarguard-node \
    && chmod +x /usr/local/bin/pasarguard-node \
    && rm -rf /tmp/pg-node /tmp/pg-node.zip

COPY start-railway.sh /start-railway.sh
RUN chmod +x /start-railway.sh /code/start.sh
# دانلود قالب رسمی صفحه‌ی ساب (subscription-template) در زمان build
RUN mkdir -p /code/templates/subscription && \
    curl -fsSL -o /code/templates/subscription/index.html \
    https://github.com/PasarGuard/subscription-template/releases/latest/download/index.html
# این خط به Railway می‌گوید پنل روی کدام پورت گوش می‌دهد تا موقع ساخت
# دامنه، پورت درست را خودش به‌صورت خودکار تشخیص دهد.
EXPOSE 8000

ENTRYPOINT ["/start-railway.sh"]
