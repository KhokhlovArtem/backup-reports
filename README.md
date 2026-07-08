# Backup Reports

PowerShell-скрипт мониторинга и отчётности по бэкапам. Сканирует указанную директорию, классифицирует файлы по давности и генерирует отчёты.

## Возможности

- Сканирование директории бэкапов с исключением указанных папок
- Генерация 3 типов отчётов: Daily (>10 дней), Weekly (>45 дней), Monthly (>60 дней)
- Создание триггер-файлов с количеством найденных файлов
- Конфигурация через JSON-файл
- Поддержка параметров командной строки
- Логирование с уровнями INFO, WARN, ERROR, SUCCESS, TRIGGER
- Коды возврата: 0 (успех), 1 (ошибка), 10 (инцидент)

## Требования

- PowerShell 5.1+
- Pester 5+ (для тестов)

## Установка

```bash
git clone https://github.com/your-org/backup-reports.git
cd backup-reports
Copy-Item config\config.example.json config\config.json
# Отредактируй config.json под свои нужды
```

## Использование

```powershell
# Запуск с конфигом по умолчанию
.\src\BackupMonitor.ps1

# Указание пути к конфигу
.\src\BackupMonitor.ps1 -Config .\config\config.json

# Справка
.\src\BackupMonitor.ps1 -Help
```

## Конфигурация

Файл `config/config.json`:

```json
{
  "BackupPath": "E:\\share\\backup",
  "ExcludeFolders": ["LongTermCopy", "!Основание"],
  "Reports": {
    "Daily": { "DaysThreshold": 10 },
    "Weekly": { "DaysThreshold": 45 },
    "Monthly": { "DaysThreshold": 60 }
  },
  "OutputPath": ".\\reports",
  "LogPath": ".\\logs",
  "TriggerPath": ".\\triggers"
}
```

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
├── config/               # Конфигурация
├── tests/                # Pester тесты
├── docs/                 # Документация
├── .github/workflows/    # GitHub Actions
├── logs/                 # Логи (gitignore)
├── reports/              # Отчёты (gitignore)
├── triggers/             # Триггеры (gitignore)
├── .gitignore
├── LICENSE
└── README.md
```

## Лицензия

MIT
