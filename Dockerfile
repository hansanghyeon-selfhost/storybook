FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG VITE_SUPABASE_KEY
ARG VITE_SUPABASE_URL

ENV VITE_SUPABASE_KEY ${VITE_SUPABASE_KEY}
ENV VITE_SUPABASE_URL ${VITE_SUPABASE_URL}

RUN yarn build-storybook

# If using npm comment out above and use below instead
# RUN npm run build

# Production image, copy all the files and run next
FROM httpd:alpine AS runner
WORKDIR /app

COPY --from=builder /app/storybook-static/ /usr/local/apache2/htdocs/
