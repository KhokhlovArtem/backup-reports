# Backup Reports

PowerShell-скрипт мониторинга и отчётности по бэкапам. Сканирует указанную директорию, классифицирует файлы по давности и генерирует отчёты.

## Возможности

- Сканирование директории бэкапов с исключением указанных папок
- Генерация 3 типов отчётов: Daily (>10 дней), Weekly (>45 дней), Monthly (>60 дней)
- Создание триггер-файлов с количеством найденных файлов
- Конфигурация через `.env` файл
- Логирование с уровнями INFO, WARN, ERROR, SUCCESS, TRIGGER
- Коды возврата: 0 (успех), 1 (ошибка), 10 (инцидент)

## Требования

- PowerShell 5.1+
- Pester 5+ (для тестов)

## Установка

```bash
git clone https://github.com/your-org/backup-reports.git
cd backup-reports
Copy-Item .env.example .env
# Отредактируй .env под свои нужды
```

## Использование

```powershell
.\src\BackupMonitor.ps1
.\src\BackupMonitor.ps1 -EnvFile C:\path\to\.env
.\src\BackupMonitor.ps1 -Help
```

## Конфигурация

Все переменные задаются в `.env` файле:

```env
# Путь к бэкапам
BACKUP_PATH=E:\share\backup

# Исключённые папки (через запятую)
EXCLUDE_FOLDERS=LongTermCopy,!Основание

# Пороговые значения (дни)
DAILY_THRESHOLD=10
WEEKLY_THRESHOLD=45
MONTHLY_THRESHOLD=60

# Каталоги вывода
OUTPUT_PATH=.\reports
LOG_PATH=.\logs
TRIGGER_PATH=.\triggers

# Хранение (дни)
LOG_RETENTION_DAYS=7
REPORT_RETENTION_DAYS=7
```

Приоритет: `.env` → дефолтные значения.

## Коды возврата

| Код | Описание |
|-----|----------|
| 0   | Успех, инцидентов не обнаружено |
| 1   | Ошибка выполнения |
| 10  | Обнаружен инцидент (файлы старше пороговых значений) |

## Структура проекта

```
backup-reports/
├── src/                  # Основной скрипт
├── tests/                # Pester тесты
├── docs/                 # Документация
├── .github/workflows/    # GitHub Actions
├── logs/                 # Логи (gitignore)
├── reports/              # Отчёты (gitignore)
├── triggers/             # Триггеры (gitignore)
├── .env.example          # Пример переменных
├── .gitignore
├── LICENSE
└── README.md
```

## Лицензия

MIT
