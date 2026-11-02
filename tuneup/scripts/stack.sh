#!/usr/bin/env bash
# stack.sh DIR [DIR...] : languages and tools per repo, as signals for LSP plugins, MCP servers and rules.
set -uo pipefail
for d in "$@"; do
  [ -d "$d" ] || continue
  echo "## $d"
  has() { [ -n "$(find "$d" -maxdepth 3 -name "$1" -not -path '*/node_modules/*' -not -path '*/bin/*' -not -path '*/obj/*' -print -quit 2>/dev/null)" ]; }
  has '*.csproj' && echo "- C# (.csproj) → csharp-lsp"
  has '*.sln' && echo "- .NET solution"
  has 'package.json' && echo "- Node/TypeScript (package.json) → typescript-lsp"
  has 'tsconfig.json' && echo "- TypeScript config"
  has 'pyproject.toml' && echo "- Python (pyproject) → pyright-lsp"; has 'requirements.txt' && echo "- Python (requirements.txt) → pyright-lsp"
  has 'go.mod' && echo "- Go → gopls-lsp"; has 'Cargo.toml' && echo "- Rust → rust-analyzer-lsp"
  has 'pom.xml' && echo "- Java (maven) → jdtls-lsp"; has 'build.gradle*' && echo "- JVM (gradle) → jdtls-lsp / kotlin-lsp"
  has '*.graphql' && echo "- GraphQL schema files"
  has 'openapi*.json' && echo "- OpenAPI document"; has 'openapi*.y*ml' && echo "- OpenAPI document"
  has 'Jenkinsfile*' && echo "- Jenkins pipelines"; has '.github' && echo "- GitHub Actions"; has '.gitlab-ci.yml' && echo "- GitLab CI"
  has 'Dockerfile*' && echo "- Docker"; has '*.tf' && echo "- Terraform"; has 'Chart.yaml' && echo "- Helm"
  has 'playwright.config.*' && echo "- Playwright → playwright plugin"; has 'jest.config.*' && echo "- Jest"; has 'vitest.config.*' && echo "- Vitest"
  has '*.Tests.csproj' && echo "- .NET test projects"
  has '*.sql' && echo "- SQL files"; has 'prisma' && echo "- Prisma"
  n=$(find "$d" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | wc -l | tr -d ' ')
  echo "- files: $n"
  echo
done
