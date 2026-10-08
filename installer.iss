#define MyAppName "StegShare"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "StegShare"
#define MyAppExeName "stegshare.exe"

[Setup]
AppId={{8F4E3E0A-7B2D-4F5B-9C1B-STEGSHARE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

OutputDir=installer
OutputBaseFilename=StegShare-{#MyAppVersion}

; Установка для текущего пользователя без прав администратора
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}

; Разрешаем выбрать папку установки
DisableDirPage=no

; Показываем выбор папки меню Пуск
DisableProgramGroupPage=no

; НЕ требуем права администратора
PrivilegesRequired=lowest

; Не создавать запрос UAC
PrivilegesRequiredOverridesAllowed=commandline

; Информация об установленном приложении
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

; Иконка установщика
SetupIconFile=windows\runner\resources\app_icon.ico

; Современный интерфейс
WizardStyle=modern

; Создаём деинсталлятор
Uninstallable=yes

; Не добавлять приложение в автозапуск
DisableStartupPrompt=yes

; x64 Flutter application
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Русский интерфейс установщика
[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

; Выбор ярлыков
[Tasks]
Name: "desktopicon"; \
    Description: "Создать ярлык на рабочем столе"; \
    GroupDescription: "Дополнительные ярлыки:"; \
    Flags: unchecked

Name: "startmenuicon"; \
    Description: "Создать ярлык в меню Пуск"; \
    GroupDescription: "Дополнительные ярлыки:"; \
    Flags: checkedonce

; Файлы Flutter-приложения
[Files]
Source: "build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: recursesubdirs createallsubdirs ignoreversion

; Ярлыки
[Icons]

; Рабочий стол — по выбору пользователя
Name: "{autodesktop}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

; Меню Пуск — по выбору пользователя
Name: "{group}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"; \
    Tasks: startmenuicon

; Удаление — всегда доступно в меню Пуск
Name: "{group}\Удалить {#MyAppName}"; \
    Filename: "{uninstallexe}"

; Запуск после установки
[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Запустить {#MyAppName}"; \
    Flags: nowait postinstall skipifsilent

; Тихое обновление запускает приложение после завершения установки.
Filename: "{app}\{#MyAppExeName}"; \
    Check: WizardSilent; \
    Flags: nowait
