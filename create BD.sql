--общий скрипт создания базы данных
--площадка
CREATE TABLE площадка (
    id_площадки  SERIAL        PRIMARY KEY,
    название     VARCHAR(150)  NOT NULL,
    город        VARCHAR(100)  NOT NULL,
    адрес        VARCHAR(255)  NOT NULL,
    CONSTRAINT uq_площадка_название_адрес UNIQUE (название, адрес)
);

--тип зала
CREATE TABLE тип_зала (
    id_типа_зала  SERIAL       PRIMARY KEY,
    название      VARCHAR(50)  NOT NULL,
    описание      VARCHAR(255) NULL,
    CONSTRAINT uq_тип_зала_название UNIQUE (название)
);

--зал
CREATE TABLE зал (
    id_зала       SERIAL       PRIMARY KEY,
    id_площадки   INTEGER      NOT NULL,
    id_типа_зала  SMALLINT     NOT NULL,
    название      VARCHAR(100) NOT NULL,
    CONSTRAINT uq_зал_площадка_название UNIQUE (id_площадки, название),
    CONSTRAINT fk_зал_площадка FOREIGN KEY (id_площадки)
        REFERENCES площадка (id_площадки),
    CONSTRAINT fk_зал_тип_зала FOREIGN KEY (id_типа_зала)
        REFERENCES тип_зала (id_типа_зала)
);


-- схема зала
CREATE TABLE схема_зала (
    id_схемы  SERIAL       PRIMARY KEY,
    id_зала   INTEGER      NOT NULL,
    название  VARCHAR(100) NOT NULL,
    CONSTRAINT uq_схема_зала_зал_название UNIQUE (id_зала, название),
    CONSTRAINT fk_схема_зала_зал FOREIGN KEY (id_зала)
        REFERENCES зал (id_зала)
);


--зона
CREATE TABLE зона (
    id_зоны   SERIAL       PRIMARY KEY,
    id_схемы  INTEGER      NOT NULL,
    название  VARCHAR(100) NOT NULL,
    это_vip   BOOLEAN      NOT NULL DEFAULT false,
    описание  VARCHAR(255) NULL,
    CONSTRAINT uq_зона_схема_название UNIQUE (id_схемы, название),
    CONSTRAINT fk_зона_схема_зала FOREIGN KEY (id_схемы)
        REFERENCES схема_зала (id_схемы)
);

--место
CREATE TABLE место (
    id_места     BIGSERIAL PRIMARY KEY,
    id_зоны      INTEGER   NOT NULL,
    номер_ряда   SMALLINT  NOT NULL,
    номер_места  SMALLINT  NOT NULL,
    CONSTRAINT uq_место_зона_ряд_место UNIQUE (id_зоны, номер_ряда, номер_места),
    CONSTRAINT chk_место_номер_ряда  CHECK (номер_ряда  > 0),
    CONSTRAINT chk_место_номер_места CHECK (номер_места > 0),
    CONSTRAINT fk_место_зона FOREIGN KEY (id_зоны)
        REFERENCES зона (id_зоны)
);

--Блок создания таблиц События и цены: тип_мероприятия, статус_события, событие, 
--место_события, занятое_место, версия_правил_цен, базовая_цена_зоны, коэффициент_времени, 
--коэффициент_спроса, правило_возврата.

--тип мероприятия
CREATE TABLE тип_мероприятия (
    id_типа_мероприятия  SMALLSERIAL PRIMARY KEY,
    название             VARCHAR(50) NOT NULL,
    CONSTRAINT uq_тип_мероприятия_название UNIQUE (название)
);

--статус события
CREATE TABLE статус_события (
    id_статуса_события  SMALLINT PRIMARY KEY,
    название            VARCHAR(50) NOT NULL,
    CONSTRAINT uq_статус_события_название UNIQUE (название)
);

--событие
CREATE TABLE событие (
    id_события           SERIAL PRIMARY KEY,
    название             VARCHAR(200) NOT NULL,
    описание             TEXT NULL,
    id_типа_мероприятия  SMALLINT NOT NULL,
    id_схемы             INTEGER NOT NULL,
    id_организатора      BIGINT NOT NULL,
    id_статуса_события   SMALLINT NOT NULL,
    дата_начала          TIMESTAMPTZ NOT NULL,
    срок_брони_мин       SMALLINT NOT NULL DEFAULT 15,
    дата_создания        TIMESTAMP NOT NULL DEFAULT now(),
    
    CONSTRAINT chk_событие_срок_брони CHECK (срок_брони_мин BETWEEN 1 AND 60),
    
    CONSTRAINT fk_событие_тип FOREIGN KEY (id_типа_мероприятия)
        REFERENCES тип_мероприятия (id_типа_мероприятия),
    CONSTRAINT fk_событие_схема FOREIGN KEY (id_схемы)
        REFERENCES схема_зала (id_схемы),
    CONSTRAINT fk_событие_статус FOREIGN KEY (id_статуса_события)
        REFERENCES статус_события (id_статуса_события)
);
--перепутала тип временой зоны
ALTER TABLE событие ALTER COLUMN дата_создания TYPE TIMESTAMP WITH TIME ZONE;

--место события 
CREATE TABLE место_события (
    id_места_события  BIGSERIAL PRIMARY KEY,
    id_события        INTEGER NOT NULL,
    id_места          BIGINT NOT NULL,
    CONSTRAINT uq_место_события_событие_место UNIQUE (id_события, id_места),
    CONSTRAINT fk_место_события_событие FOREIGN KEY (id_события)
        REFERENCES событие (id_события),
    CONSTRAINT fk_место_события_место FOREIGN KEY (id_места)
        REFERENCES место (id_места)
);

--занятое место (для защиты от двойной продажи)
CREATE TABLE занятое_место (
    id_места_события BIGINT PRIMARY KEY,
    CONSTRAINT fk_занятое_место FOREIGN KEY (id_места_события)
        REFERENCES место_события (id_места_события)
);

--добавление связи билета с его занятостью
ALTER TABLE билет 
ADD CONSTRAINT fk_билет_занятое_место 
FOREIGN KEY (id_места_события) 
REFERENCES занятое_место (id_места_события);

--версия правил цен
CREATE TABLE версия_правил_цен (
    id_версии     SERIAL PRIMARY KEY,
    id_события    INTEGER NOT NULL,
    номер_версии  SMALLINT NOT NULL,
    действует_с   TIMESTAMPTZ NOT NULL,
    дата_создания TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    CONSTRAINT chk_версия_номер CHECK (номер_версии > 0),
    CONSTRAINT uq_версия_номер UNIQUE (id_события, номер_версии),
    CONSTRAINT uq_версия_дата UNIQUE (id_события, действует_с),
    
    CONSTRAINT fk_версия_событие FOREIGN KEY (id_события)
        REFERENCES событие (id_события)
);

--базовая цена зоны
CREATE TABLE базовая_цена_зоны (
    id_версии       INTEGER NOT NULL,
    id_зоны         INTEGER NOT NULL,
    базовая_цена    NUMERIC(12,2) NOT NULL,
    учитывать_спрос BOOLEAN NOT NULL DEFAULT true,
    
    PRIMARY KEY (id_версии, id_зоны),
    CONSTRAINT chk_базовая_цена CHECK (базовая_цена >= 0),
    
    CONSTRAINT fk_базовая_цена_версия FOREIGN KEY (id_версии)
        REFERENCES версия_правил_цен (id_версии),
    CONSTRAINT fk_базовая_цена_зона FOREIGN KEY (id_зоны)
        REFERENCES зона (id_зоны)
);


--коэффициент времени
CREATE TABLE коэффициент_времени (
    id_версии           INTEGER NOT NULL,
    мин_дней_до_события SMALLINT NOT NULL,
    коэффициент         NUMERIC(5,3) NOT NULL,
    
    PRIMARY KEY (id_версии, мин_дней_до_события),
    CONSTRAINT chk_коэф_время_дни CHECK (мин_дней_до_события >= 0),
    CONSTRAINT chk_коэф_время_значение CHECK (коэффициент > 0),
    
    CONSTRAINT fk_коэф_время_версия FOREIGN KEY (id_версии)
        REFERENCES версия_правил_цен (id_версии)
);

--коэффициент спроса
CREATE TABLE коэффициент_спроса (
    id_версии             INTEGER NOT NULL,
    порог_заполнения_проц NUMERIC(5,2) NOT NULL,
    коэффициент           NUMERIC(5,3) NOT NULL,
    
    PRIMARY KEY (id_версии, порог_заполнения_проц),
    CONSTRAINT chk_коэф_спрос_проц CHECK (порог_заполнения_проц BETWEEN 0 AND 100),
    CONSTRAINT chk_коэф_спрос_значение CHECK (коэффициент > 0),
    
    CONSTRAINT fk_коэф_спрос_версия FOREIGN KEY (id_версии)
        REFERENCES версия_правил_цен (id_версии)
);

--правило возврата 
CREATE TABLE правило_возврата (
    id_события          INTEGER NOT NULL,
    мин_дней_до_события SMALLINT NOT NULL,
    процент_возврата    NUMERIC(5,2) NOT NULL,
    PRIMARY KEY (id_события, мин_дней_до_события),
    CONSTRAINT chk_возврат_дни CHECK (мин_дней_до_события >= 0),
    CONSTRAINT chk_возврат_процент CHECK (процент_возврата BETWEEN 0 AND 100),
    CONSTRAINT fk_правило_возврата_событие FOREIGN KEY (id_события)
        REFERENCES событие (id_события)
);

--Блок создания таблиц: Пользователи: роль_пользователя, пользователь.

--роль пользователя
CREATE TABLE роль_пользователя (
    id_роли   SMALLINT PRIMARY KEY,
    название  VARCHAR(50) NOT NULL,
    CONSTRAINT uq_роль_пользователя_название UNIQUE (название)
);

--пользователь
CREATE TABLE пользователь (
    id_пользователя  BIGSERIAL PRIMARY KEY,
    эл_почта         VARCHAR(254) NOT NULL,
    имя              VARCHAR(60)  NOT NULL,
    фамилия              VARCHAR(60)  NOT NULL,
    телефон              VARCHAR(10)  NULL,
    id_роли   SMALLINT,
    дата_создания TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_пользователь_эл_почта UNIQUE (эл_почта),
    CONSTRAINT uq_пользователь_телефон UNIQUE (телефон),
    CONSTRAINT fk_роль_пользователя FOREIGN KEY (id_роли)
        REFERENCES роль_пользователя (id_роли)
);

--добавление связи между событием и организатором 
ALTER TABLE событие
    ADD CONSTRAINT fk_событие_организатор 
    FOREIGN KEY (id_организатора) 
    REFERENCES пользователь (id_пользователя);

--Блок создания таблиц: Продажи: статус_билета, билет, платеж, возврат.

--статус билета
CREATE TABLE статус_билета (
    id_статуса_билета  SMALLINT PRIMARY KEY,
    название           VARCHAR(50) NOT NULL,
    занимает_место BOOLEAN NOT NULL,
    CONSTRAINT uq_статус_билета_название UNIQUE (название)
);

--билет
CREATE TABLE билет (
    id_билета              BIGSERIAL PRIMARY KEY,
    id_места_события       BIGINT NOT NULL,
    id_покупателя	       BIGINT NOT NULL,
    id_версии              INTEGER NOT NULL,
    id_статуса_билета      SMALLINT NOT NULL,
    цена_билета            NUMERIC(12,2) NOT NULL,
    дата_создания          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_билет_цена CHECK (цена_билета >= 0),
    CONSTRAINT fk_место_события FOREIGN KEY (id_места_события)
        REFERENCES место_события (id_места_события),
    CONSTRAINT fk_пользователь FOREIGN KEY (id_покупателя)
        REFERENCES пользователь (id_пользователя),
    CONSTRAINT fk_версия_правил_цен FOREIGN KEY (id_версии)
        REFERENCES версия_правил_цен (id_версии),
    CONSTRAINT fk_статус_билета FOREIGN KEY (id_статуса_билета)
        REFERENCES статус_билета (id_статуса_билета)
);

--платеж
CREATE TABLE платеж (
    id_платежа         BIGSERIAL PRIMARY KEY,
    id_билета          BIGINT NOT NULL,
    дата_платежа       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_платеж_билет UNIQUE (id_билета), 
    CONSTRAINT fk_платеж_билет FOREIGN KEY (id_билета)
        REFERENCES билет (id_билета)
);

--возврат 
CREATE TABLE возврат (
    id_возврата        BIGSERIAL PRIMARY KEY,
    id_платежа         BIGINT NOT NULL,
    сумма_возврата     NUMERIC(12,2) NOT NULL,
    причина 		   VARCHAR(255) NULL,	
    дата_возврата      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_возврат_сумма CHECK (сумма_возврата >= 0),
    CONSTRAINT uq_возврат_платеж UNIQUE (id_платежа), 
    CONSTRAINT fk_возврат_платеж FOREIGN KEY (id_платежа)
        REFERENCES платеж (id_платежа)
);