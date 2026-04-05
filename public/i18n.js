/* ============================================================
   i18n — мультиязычность админ-панели
   Языки: ru, en, tr, it, ro, bg, bs
   ============================================================ */

const LANGS = {
  ru: { label: "Русский",       flag: "🇷🇺" },
  en: { label: "English",       flag: "🇺🇸" },
  tr: { label: "Türkçe",        flag: "🇹🇷" },
  it: { label: "Italiano",      flag: "🇮🇹" },
  ro: { label: "Română",        flag: "🇷🇴" },
  bg: { label: "Български",     flag: "🇧🇬" },
  bs: { label: "Bosanski",      flag: "🇧🇦" },
};

const T = {
  /* ── Sidebar (общий для всех страниц) ── */
  "sidebar.screens": {
    ru: "📺 Экраны",     en: "📺 Screens",     tr: "📺 Ekranlar",    it: "📺 Schermi",    ro: "📺 Ecrane",     bg: "📺 Екрани",     bs: "📺 Ekrani"
  },
  "sidebar.playlists": {
    ru: "📋 Плейлисты",  en: "📋 Playlists",   tr: "📋 Oynatma Listeleri", it: "📋 Playlist", ro: "📋 Playlisturi", bg: "📋 Плейлисти", bs: "📋 Plejliste"
  },
  "sidebar.media": {
    ru: "📁 Медиа",      en: "📁 Media",       tr: "📁 Medya",       it: "📁 Media",      ro: "📁 Media",      bg: "📁 Медия",      bs: "📁 Mediji"
  },
  "sidebar.scenarios": {
    ru: "⏰ Сценарии",   en: "⏰ Scenarios",   tr: "⏰ Senaryolar",  it: "⏰ Scenari",    ro: "⏰ Scenarii",   bg: "⏰ Сценарии",   bs: "⏰ Scenariji"
  },
  "sidebar.settings": {
    ru: "⚙️ Настройки",  en: "⚙️ Settings",    tr: "⚙️ Ayarlar",     it: "⚙️ Impostazioni", ro: "⚙️ Setări",    bg: "⚙️ Настройки",  bs: "⚙️ Postavke"
  },

  /* ── Screens ── */
  "screens.title": {
    ru: "Экраны и мониторинг", en: "Screens & Monitoring", tr: "Ekranlar ve İzleme", it: "Schermi e Monitoraggio", ro: "Ecrane și Monitorizare", bg: "Екрани и мониторинг", bs: "Ekrani i Monitoring"
  },
  "screens.manage_groups": {
    ru: "📂 Управление группами", en: "📂 Manage Groups", tr: "📂 Grupları Yönet", it: "📂 Gestisci Gruppi", ro: "📂 Gestionare Grupuri", bg: "📂 Управление на групи", bs: "📂 Upravljanje Grupama"
  },
  "screens.online": { ru: "Онлайн", en: "Online", tr: "Çevrimiçi", it: "Online", ro: "Online", bg: "Онлайн", bs: "Online" },
  "screens.offline": { ru: "Оффлайн", en: "Offline", tr: "Çevrimdışı", it: "Offline", ro: "Offline", bg: "Офлайн", bs: "Offline" },
  "screens.waiting": { ru: "Ожидание", en: "Waiting", tr: "Bekleniyor", it: "In attesa", ro: "În așteptare", bg: "Изчакване", bs: "Čekanje" },
  "screens.total": { ru: "Всего", en: "Total", tr: "Toplam", it: "Totale", ro: "Total", bg: "Общо", bs: "Ukupno" },
  "screens.group_filter": { ru: "Группа:", en: "Group:", tr: "Grup:", it: "Gruppo:", ro: "Grup:", bg: "Група:", bs: "Grupa:" },
  "screens.all_groups": { ru: "Все группы", en: "All groups", tr: "Tüm gruplar", it: "Tutti i gruppi", ro: "Toate grupurile", bg: "Всички групи", bs: "Sve grupe" },
  "screens.no_screens": { ru: "Нет экранов. Зарегистрируйте первое устройство.", en: "No screens. Register your first device.", tr: "Ekran yok. İlk cihazınızı kaydedin.", it: "Nessuno schermo. Registra il primo dispositivo.", ro: "Niciun ecran. Înregistrați primul dispozitiv.", bg: "Няма екрани. Регистрирайте първото устройство.", bs: "Nema ekrana. Registrirajte prvi uređaj." },
  "screens.reg_link": { ru: "Регистрация нового экрана:", en: "Register new screen:", tr: "Yeni ekran kaydet:", it: "Registra nuovo schermo:", ro: "Înregistrare ecran nou:", bg: "Регистрация на нов екран:", bs: "Registriraj novi ekran:" },
  "screens.copy": { ru: "📋 Копировать", en: "📋 Copy", tr: "📋 Kopyala", it: "📋 Copia", ro: "📋 Copiază", bg: "📋 Копиране", bs: "📋 Kopiraj" },
  "screens.ip": { ru: "IP", en: "IP", tr: "IP", it: "IP", ro: "IP", bg: "IP", bs: "IP" },
  "screens.group": { ru: "Группа", en: "Group", tr: "Grup", it: "Gruppo", ro: "Grup", bg: "Група", bs: "Grupa" },
  "screens.playlist": { ru: "Плейлист", en: "Playlist", tr: "Oynatma listesi", it: "Playlist", ro: "Playlist", bg: "Плейлист", bs: "Plejlista" },
  "screens.default_media": { ru: "Контент по умолч.", en: "Default content", tr: "Varsayılan içerik", it: "Contenuto predef.", ro: "Conținut implicit", bg: "Съдържание по под.", bs: "Zadani sadržaj" },
  "screens.not_assigned": { ru: "Не назначен", en: "Not assigned", tr: "Atanmadı", it: "Non assegnato", ro: "Neatribuit", bg: "Не е назначен", bs: "Nije dodijeljeno" },
  "screens.not_set": { ru: "Не выбран", en: "Not set", tr: "Ayarlanmadı", it: "Non impostato", ro: "Nesetat", bg: "Не е избрано", bs: "Nije postavljeno" },
  "screens.heartbeat": { ru: "Heartbeat", en: "Heartbeat", tr: "Heartbeat", it: "Heartbeat", ro: "Heartbeat", bg: "Heartbeat", bs: "Heartbeat" },
  "screens.just_now": { ru: "только что", en: "just now", tr: "şimdi", it: "proprio ora", ro: "chiar acum", bg: "току-що", bs: "upravo sada" },
  "screens.min_ago": { ru: "мин назад", en: "min ago", tr: "dk önce", it: "min fa", ro: "min în urmă", bg: "мин назад", bs: "min prije" },
  "screens.h_ago": { ru: "ч назад", en: "h ago", tr: "s önce", it: "ore fa", ro: "ore în urmă", bg: "ч назад", bs: "h prije" },
  "screens.settings": { ru: "⚙️ Настроить", en: "⚙️ Settings", tr: "⚙️ Ayarlar", it: "⚙️ Impostazioni", ro: "⚙️ Setări", bg: "⚙️ Настройки", bs: "⚙️ Postavke" },
  "screens.modal_title": { ru: "Настройки экрана", en: "Screen Settings", tr: "Ekran Ayarları", it: "Impostazioni schermo", ro: "Setări ecran", bg: "Настройки на екрана", bs: "Postavke ekrana" },
  "screens.name": { ru: "Имя", en: "Name", tr: "Ad", it: "Nome", ro: "Nume", bg: "Име", bs: "Ime" },
  "screens.no_group": { ru: "Без группы", en: "No group", tr: "Grupsuz", it: "Senza gruppo", ro: "Fără grup", bg: "Без група", bs: "Bez grupe" },
  "screens.save": { ru: "Сохранить", en: "Save", tr: "Kaydet", it: "Salva", ro: "Salvează", bg: "Запази", bs: "Sačuvaj" },
  "screens.groups_title": { ru: "Группы экранов", en: "Screen Groups", tr: "Ekran Grupları", it: "Gruppi schermi", ro: "Grupuri ecrane", bg: "Групи екрани", bs: "Grupe ekrana" },
  "screens.group_name_ph": { ru: "Название группы", en: "Group name", tr: "Grup adı", it: "Nome gruppo", ro: "Nume grup", bg: "Име на група", bs: "Naziv grupe" },
  "screens.create": { ru: "Создать", en: "Create", tr: "Oluştur", it: "Crea", ro: "Creează", bg: "Създай", bs: "Kreiraj" },
  "screens.no_groups": { ru: "Нет групп", en: "No groups", tr: "Grup yok", it: "Nessun gruppo", ro: "Niciun grup", bg: "Няма групи", bs: "Nema grupa" },
  "screens.screens_count": { ru: "экран(ов)", en: "screen(s)", tr: "ekran", it: "schermi", ro: "ecrane", bg: "екран(а)", bs: "ekran(a)" },
  "screens.copy_ok": { ru: "Ссылка скопирована!", en: "Link copied!", tr: "Bağlantı kopyalandı!", it: "Link copiato!", ro: "Link copiat!", bg: "Линкът е копиран!", bs: "Link kopiran!" },

  /* ── Playlists ── */
  "playlists.title": {
    ru: "Плейлисты", en: "Playlists", tr: "Oynatma Listeleri", it: "Playlist", ro: "Playlisturi", bg: "Плейлисти", bs: "Plejliste"
  },
  "playlists.name_ph": { ru: "Название нового плейлиста", en: "New playlist name", tr: "Yeni liste adı", it: "Nome nuova playlist", ro: "Nume playlist nou", bg: "Име на нов плейлист", bs: "Naziv nove plejliste" },
  "playlists.add_btn": { ru: "＋ Создать", en: "＋ Create", tr: "＋ Oluştur", it: "＋ Crea", ro: "＋ Creează", bg: "＋ Създай", bs: "＋ Kreiraj" },
  "playlists.no_playlists": { ru: "Нет плейлистов. Создайте первый.", en: "No playlists. Create the first one.", tr: "Oynatma listesi yok. İlkini oluşturun.", it: "Nessuna playlist. Crea la prima.", ro: "Niciun playlist. Creați primul.", bg: "Няма плейлисти. Създайте първия.", bs: "Nema plejlisti. Kreirajte prvu." },
  "playlists.edit_title": { ru: "Редактирование плейлиста", en: "Edit Playlist", tr: "Listeyi Düzenle", it: "Modifica Playlist", ro: "Editare playlist", bg: "Редакция на плейлист", bs: "Uredi plejlistu" },
  "playlists.rename": { ru: "Переименовать", en: "Rename", tr: "Yeniden adlandır", it: "Rinomina", ro: "Redenumește", bg: "Преименувай", bs: "Preimenuj" },
  "playlists.media_title": { ru: "Медиа в плейлисте", en: "Media in playlist", tr: "Listedeki medya", it: "Media nella playlist", ro: "Media în playlist", bg: "Медия в плейлиста", bs: "Mediji u plejlisti" },
  "playlists.empty_playlist": { ru: "Плейлист пуст. Добавьте медиа.", en: "Playlist is empty. Add media.", tr: "Liste boş. Medya ekleyin.", it: "Playlist vuota. Aggiungi media.", ro: "Playlistul e gol. Adaugă media.", bg: "Плейлистът е празен. Добавете медия.", bs: "Plejlista je prazna. Dodajte medije." },
  "playlists.add_media_title": { ru: "Добавить медиа", en: "Add Media", tr: "Medya Ekle", it: "Aggiungi Media", ro: "Adaugă Media", bg: "Добавяне на медия", bs: "Dodaj medije" },
  "playlists.select_media": { ru: "— Выберите медиафайл —", en: "— Select media file —", tr: "— Medya dosyası seçin —", it: "— Seleziona file —", ro: "— Selectează fișier —", bg: "— Изберете файл —", bs: "— Odaberite datoteku —" },
  "playlists.add": { ru: "Добавить", en: "Add", tr: "Ekle", it: "Aggiungi", ro: "Adaugă", bg: "Добави", bs: "Dodaj" },
  "playlists.upload_title": { ru: "Загрузить файл в плейлист", en: "Upload file to playlist", tr: "Listeye dosya yükle", it: "Carica file nella playlist", ro: "Încarcă fișier în playlist", bg: "Качи файл в плейлист", bs: "Učitaj datoteku u plejlistu" },
  "playlists.duration_ph": { ru: "Секунды", en: "Seconds", tr: "Saniye", it: "Secondi", ro: "Secunde", bg: "Секунди", bs: "Sekunde" },
  "playlists.upload_err": { ru: "Ошибка загрузки", en: "Upload error", tr: "Yükleme hatası", it: "Errore caricamento", ro: "Eroare încărcare", bg: "Грешка при качване", bs: "Greška pri učitavanju" },
  "playlists.del_confirm": { ru: "Удалить плейлист?", en: "Delete playlist?", tr: "Liste silinsin mi?", it: "Eliminare playlist?", ro: "Ștergi playlistul?", bg: "Изтриване на плейлист?", bs: "Obrisati plejlistu?" },

  /* ── Media ── */
  "media.title": {
    ru: "Медиафайлы", en: "Media Files", tr: "Medya Dosyaları", it: "File Multimediali", ro: "Fișiere Media", bg: "Медийни файлове", bs: "Medijske datoteke"
  },
  "media.upload": { ru: "📤 Загрузить", en: "📤 Upload", tr: "📤 Yükle", it: "📤 Carica", ro: "📤 Încarcă", bg: "📤 Качи", bs: "📤 Učitaj" },
  "media.no_media": { ru: "Нет медиафайлов.", en: "No media files.", tr: "Medya dosyası yok.", it: "Nessun file multimediale.", ro: "Niciun fișier media.", bg: "Няма медийни файлове.", bs: "Nema medijskih datoteka." },
  "media.delete": { ru: "🗑️ Удалить", en: "🗑️ Delete", tr: "🗑️ Sil", it: "🗑️ Elimina", ro: "🗑️ Șterge", bg: "🗑️ Изтрий", bs: "🗑️ Obriši" },
  "media.del_confirm": { ru: "Удалить медиафайл?", en: "Delete media file?", tr: "Medya silinsin mi?", it: "Eliminare file?", ro: "Ștergi fișierul?", bg: "Изтриване на файл?", bs: "Obrisati datoteku?" },
  "media.pending": { ru: "Ожидание", en: "Pending", tr: "Bekliyor", it: "In attesa", ro: "În așteptare", bg: "Изчакване", bs: "Na čekanju" },
  "media.processing": { ru: "Конвертация", en: "Converting", tr: "Dönüştürülüyor", it: "Conversione", ro: "Conversie", bg: "Конвертиране", bs: "Konvertiranje" },
  "media.completed": { ru: "Готово", en: "Ready", tr: "Hazır", it: "Pronto", ro: "Gata", bg: "Готово", bs: "Spremno" },
  "media.failed": { ru: "Ошибка", en: "Failed", tr: "Hata", it: "Errore", ro: "Eroare", bg: "Грешка", bs: "Greška" },
  "media.upload_err": { ru: "Ошибка загрузки: ", en: "Upload error: ", tr: "Yükleme hatası: ", it: "Errore caricamento: ", ro: "Eroare încărcare: ", bg: "Грешка при качване: ", bs: "Greška pri učitavanju: " },
  "media.err_generic": { ru: "Ошибка: ", en: "Error: ", tr: "Hata: ", it: "Errore: ", ro: "Eroare: ", bg: "Грешка: ", bs: "Greška: " },
  "media.unknown_err": { ru: "Неизвестная ошибка", en: "Unknown error", tr: "Bilinmeyen hata", it: "Errore sconosciuto", ro: "Eroare necunoscută", bg: "Неизвестна грешка", bs: "Nepoznata greška" },

  /* ── Scenarios ── */
  "scenarios.title": {
    ru: "Сценарии", en: "Scenarios", tr: "Senaryolar", it: "Scenari", ro: "Scenarii", bg: "Сценарии", bs: "Scenariji"
  },
  "scenarios.create": { ru: "＋ Создать сценарий", en: "＋ Create Scenario", tr: "＋ Senaryo Oluştur", it: "＋ Crea Scenario", ro: "＋ Creează Scenariu", bg: "＋ Създай сценарий", bs: "＋ Kreiraj Scenarij" },
  "scenarios.check": { ru: "▶ Проверить", en: "▶ Check Now", tr: "▶ Şimdi Kontrol Et", it: "▶ Verifica Ora", ro: "▶ Verifică Acum", bg: "▶ Провери сега", bs: "▶ Provjeri Sada" },
  "scenarios.info": {
    ru: "Как это работает: Сценарии автоматически переключают плейлисты на экранах по расписанию. Укажите дни недели, время и плейлист — сервер будет проверять каждые 60 секунд.",
    en: "How it works: Scenarios automatically switch playlists on screens on a schedule. Specify days, time, and playlist — the server checks every 60 seconds.",
    tr: "Nasıl çalışır: Senaryolar, ekranlardaki oynatma listelerini zamanlamaya göre otomatik olarak değiştirir. Günleri, saati ve listeyi belirtin — sunucu her 60 saniyede bir kontrol eder.",
    it: "Come funziona: Gli scenari cambiano automaticamente le playlist sugli schermi in base a una pianificazione. Specifica giorni, ora e playlist — il server controlla ogni 60 secondi.",
    ro: "Cum funcționează: Scenariile schimbă automat playlisturile pe ecrane conform unui program. Specificați zilele, ora și playlistul — serverul verifică la fiecare 60 de secunde.",
    bg: "Как работи: Сценариите автоматично превключват плейлисти на екраните по разписание. Посочете дни, време и плейлист — сървърът проверява на всеки 60 секунди.",
    bs: "Kako radi: Scenariji automatski mijenjaju plejliste na ekranima prema rasporedu. Navedite dane, vrijeme i plejlistu — server provjerava svakih 60 sekundi."
  },
  "scenarios.no_scenarios": { ru: "Нет сценариев. Создайте первый.", en: "No scenarios. Create the first one.", tr: "Senaryo yok. İlkini oluşturun.", it: "Nessuno scenario. Crea il primo.", ro: "Niciun scenariu. Creați primul.", bg: "Няма сценарии. Създайте първия.", bs: "Nema scenarija. Kreirajte prvi." },
  "scenarios.new_title": { ru: "Новый сценарий", en: "New Scenario", tr: "Yeni Senaryo", it: "Nuovo Scenario", ro: "Scenariu Nou", bg: "Нов сценарий", bs: "Novi Scenarij" },
  "scenarios.edit_title": { ru: "Редактировать сценарий", en: "Edit Scenario", tr: "Senaryoyu Düzenle", it: "Modifica Scenario", ro: "Editare Scenariu", bg: "Редакция на сценарий", bs: "Uredi Scenarij" },
  "scenarios.name_ph": { ru: "Например: Утренний эфир", en: "E.g.: Morning Show", tr: "Örn: Sabah Yayını", it: "Es.: Trasmissione Mattutina", ro: "Ex: Emisiunea de Dimineață", bg: "Напр: Сутрешна програма", bs: "Npr: Jutarnji Program" },
  "scenarios.playlist": { ru: "Плейлист", en: "Playlist", tr: "Oynatma Listesi", it: "Playlist", ro: "Playlist", bg: "Плейлист", bs: "Plejlista" },
  "scenarios.group": { ru: "Группа экранов", en: "Screen Group", tr: "Ekran Grubu", it: "Gruppo Schermi", ro: "Grup Ecrane", bg: "Група екрани", bs: "Grupa Ekrana" },
  "scenarios.all_screens": { ru: "Все экраны", en: "All screens", tr: "Tüm ekranlar", it: "Tutti gli schermi", ro: "Toate ecranele", bg: "Всички екрани", bs: "Svi ekrani" },
  "scenarios.schedule": { ru: "Расписание", en: "Schedule", tr: "Zamanlama", it: "Pianificazione", ro: "Program", bg: "Разписание", bs: "Raspored" },
  "scenarios.days": { ru: "Дни недели", en: "Days of week", tr: "Haftanın günleri", it: "Giorni della settimana", ro: "Zilele săptămânii", bg: "Дни от седмицата", bs: "Dani u sedmici" },
  "scenarios.time_from": { ru: "Время от", en: "Time from", tr: "Başlangıç saati", it: "Ora da", ro: "Ora de la", bg: "Начален час", bs: "Vrijeme od" },
  "scenarios.time_to": { ru: "Время до", en: "Time to", tr: "Bitiş saati", it: "Ora a", ro: "Ora până la", bg: "Краен час", bs: "Vrijeme do" },
  "scenarios.date_from": { ru: "Дата начала", en: "Start date", tr: "Başlangıç tarihi", it: "Data inizio", ro: "Data început", bg: "Начална дата", bs: "Datum početka" },
  "scenarios.date_to": { ru: "Дата окончания", en: "End date", tr: "Bitiş tarihi", it: "Data fine", ro: "Data sfârșit", bg: "Крайна дата", bs: "Datum kraja" },
  "scenarios.priority": { ru: "Приоритет", en: "Priority", tr: "Öncelik", it: "Priorità", ro: "Prioritate", bg: "Приоритет", bs: "Prioritet" },
  "scenarios.enabled": { ru: "Активен", en: "Enabled", tr: "Aktif", it: "Abilitato", ro: "Activat", bg: "Активен", bs: "Omogućeno" },
  "scenarios.save": { ru: "Сохранить", en: "Save", tr: "Kaydet", it: "Salva", ro: "Salvează", bg: "Запази", bs: "Sačuvaj" },
  "scenarios.del_confirm": { ru: "Удалить сценарий?", en: "Delete scenario?", tr: "Senaryo silinsin mi?", it: "Eliminare scenario?", ro: "Ștergi scenariul?", bg: "Изтриване на сценарий?", bs: "Obrisati scenarij?" },
  "scenarios.check_applied": { ru: " экран(ам)", en: " screen(s)", tr: " ekrana", it: " schermo(i)", ro: " ecran(e)", bg: " екран(а)", bs: " ekran(a)" },
  "scenarios.check_none": { ru: "Нет активных сценариев для текущего времени", en: "No active scenarios for current time", tr: "Şu an için aktif senaryo yok", it: "Nessuno scenario attivo per l'ora corrente", ro: "Niciun scenariu activ la ora curentă", bg: "Няма активни сценарии за текущото време", bs: "Nema aktivnih scenarija za trenutno vrijeme" },
  "scenarios.every_day": { ru: "Каждый день", en: "Every day", tr: "Her gün", it: "Ogni giorno", ro: "În fiecare zi", bg: "Всеки ден", bs: "Svaki dan" },
  /* Day names */
  "scenarios.mon": { ru: "Пн", en: "Mon", tr: "Pzt", it: "Lun", ro: "Lun", bg: "Пон", bs: "Pon" },
  "scenarios.tue": { ru: "Вт", en: "Tue", tr: "Sal", it: "Mar", ro: "Mar", bg: "Вто", bs: "Uto" },
  "scenarios.wed": { ru: "Ср", en: "Wed", tr: "Çar", it: "Mer", ro: "Mie", bg: "Сря", bs: "Sri" },
  "scenarios.thu": { ru: "Чт", en: "Thu", tr: "Per", it: "Gio", ro: "Joi", bg: "Чет", bs: "Čet" },
  "scenarios.fri": { ru: "Пт", en: "Fri", tr: "Cum", it: "Ven", ro: "Vin", bg: "Пет", bs: "Pet" },
  "scenarios.sat": { ru: "Сб", en: "Sat", tr: "Cmt", it: "Sab", ro: "Sâm", bg: "Съб", bs: "Sub" },
  "scenarios.sun": { ru: "Вс", en: "Sun", tr: "Paz", it: "Dom", ro: "Dum", bg: "Нед", bs: "Ned" },
  "scenarios.all_screens_label": { ru: "Все экраны", en: "All screens", tr: "Tüm ekranlar", it: "Tutti gli schermi", ro: "Toate ecranele", bg: "Всички екрани", bs: "Svi ekrani" },
  "scenarios.not_assigned": { ru: "—", en: "—", tr: "—", it: "—", ro: "—", bg: "—", bs: "—" },

  /* ── Settings ── */
  "settings.title": {
    ru: "Настройки", en: "Settings", tr: "Ayarlar", it: "Impostazioni", ro: "Setări", bg: "Настройки", bs: "Postavke"
  },
  "settings.default_media": {
    ru: "Контент по умолчанию для всех экранов", en: "Default content for all screens", tr: "Tüm ekranlar için varsayılan içerik", it: "Contenuto predefinito per tutti gli schermi", ro: "Conținut implicit pentru toate ecranele", bg: "Съдържание по подразбиране за всички екрани", bs: "Zadani sadržaj za sve ekrane"
  },
  "settings.default_media_desc": {
    ru: "Это медиа будет показываться на всех экранах, у которых не назначен плейлист и не выбран свой контент по умолчанию.",
    en: "This media will be shown on all screens that have no playlist assigned and no individual default content.",
    tr: "Bu medya, atanmış oynatma listesi ve bireysel varsayılan içeriği olmayan tüm ekranlarda gösterilecektir.",
    it: "Questo media verrà mostrato su tutti gli schermi che non hanno una playlist assegnata e nessun contenuto predefinito individuale.",
    ro: "Acest media va fi afișat pe toate ecranele care nu au un playlist asignat și nici un conținut implicit individual.",
    bg: "Тази медия ще се показва на всички екрани, които нямат назначен плейлист и нямат индивидуално съдържание по подразбиране.",
    bs: "Ovaj medij će se prikazivati na svim ekranima koji nemaju dodijeljenu plejlistu niti pojedinačni zadani sadržaj."
  },
  "settings.select_media": {
    ru: "Выберите медиафайл", en: "Select media file", tr: "Medya dosyası seçin", it: "Seleziona file", ro: "Selectează fișier", bg: "Изберете файл", bs: "Odaberite datoteku"
  },
  "settings.not_set": {
    ru: "Не выбран", en: "Not set", tr: "Ayarlanmadı", it: "Non impostato", ro: "Nesetat", bg: "Не е избрано", bs: "Nije postavljeno"
  },
  "settings.save": {
    ru: "Сохранить", en: "Save", tr: "Kaydet", it: "Salva", ro: "Salvează", bg: "Запази", bs: "Sačuvaj"
  },
  "settings.saved": {
    ru: "✓ Сохранено", en: "✓ Saved", tr: "✓ Kaydedildi", it: "✓ Salvato", ro: "✓ Salvat", bg: "✓ Запазено", bs: "✓ Sačuvano"
  },

  /* ── Login ── */
  "login.title": {
    ru: "Вход в Digital Signage", en: "Digital Signage Login", tr: "Digital Signage Girişi", it: "Accesso Digital Signage", ro: "Autentificare Digital Signage", bg: "Вход в Digital Signage", bs: "Prijava na Digital Signage"
  },
  "login.heading": { ru: "Авторизация", en: "Login", tr: "Giriş", it: "Accesso", ro: "Autentificare", bg: "Вход", bs: "Prijava" },
  "login.login_label": { ru: "Логин", en: "Login", tr: "Kullanıcı adı", it: "Login", ro: "Utilizator", bg: "Потребител", bs: "Korisničko ime" },
  "login.password": { ru: "Пароль", en: "Password", tr: "Parola", it: "Password", ro: "Parolă", bg: "Парола", bs: "Lozinka" },
  "login.btn": { ru: "Войти", en: "Sign In", tr: "Giriş Yap", it: "Accedi", ro: "Autentificare", bg: "Вход", bs: "Prijava" },
  "login.error": { ru: "Ошибка авторизации", en: "Invalid credentials", tr: "Geçersiz bilgiler", it: "Credenziali non valide", ro: "Credențiale invalide", bg: "Грешни данни", bs: "Neispravni podaci" },
};

/* ── API ── */
function setLang(code) {
  if (!LANGS[code]) return;
  localStorage.setItem("ds_lang", code);
  applyLang();
}

function getLang() {
  return localStorage.getItem("ds_lang") || "ru";
}

function t(key) {
  const entry = T[key];
  if (!entry) return key;
  return entry[getLang()] || entry.ru || key;
}

function applyLang() {
  const lang = getLang();
  // Обновляем все элементы с data-i18n
  document.querySelectorAll("[data-i18n]").forEach(el => {
    const key = el.getAttribute("data-i18n");
    const val = t(key);
    if (el.tagName === "INPUT" || el.tagName === "BUTTON") {
      if (el.hasAttribute("placeholder")) el.placeholder = val;
      else if (el.tagName === "BUTTON") el.textContent = val;
    } else {
      el.innerHTML = val;
    }
  });
  // Обновляем <html lang>
  document.documentElement.lang = lang;
  // Обновляем селектор языка если есть
  const sel = document.getElementById("langSelect");
  if (sel) sel.value = lang;
}

function renderLangSelect() {
  const lang = getLang();
  let html = '<select id="langSelect" class="select lang-select" onchange="setLang(this.value)">';
  for (const [code, info] of Object.entries(LANGS)) {
    html += `<option value="${code}" ${code === lang ? "selected" : ""}>${info.flag} ${info.label}</option>`;
  }
  html += "</select>";
  return html;
}
