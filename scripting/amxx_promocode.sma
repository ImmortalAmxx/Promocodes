#include <amxmodx>
#include <sqlx>

#define FMT_CVAR(%0) fmt("%L", LANG_SERVER, %0)

enum {
    SQL_CREATE_TABLE,
    SQL_ADD_PROMOCODE,
    SQL_USE_PROMOCODE,
    SLQ_UPDATE_PROMOCODE,
    SQL_DELETE_PROMOCODE
};

enum any: CvarStruct {
    CVAR_SQL_HOST[64],
    CVAR_SQL_USER[64],
    CVAR_SQL_PASS[64],
    CVAR_SQL_DB[64],
    CVAR_SQL_TABLE[64],
    CVAR_ACCESS[32],
    CVAR_CMD_ADD[32],
    CVAR_CMD_USE[32]
};

enum any: ForwardStruct {
    FORWARD_ADD,
    FORWARD_USE_PRE,
    FORWARD_USE_POST
};

// Стандартный путь к lang файлам.
//
// Standard path to lang files.
new const LANG_PATH[] = "addons/amxmodx/data/lang";

// Название lang словаря.
//
// The name of the lang dictionary.
new const LANG_NAME[] = "promocode.txt";

// Название конфиг файла, закоментировать, если не нужно авто-создание.
//
// Name of the config file, comment out if you don't want to auto-create it.
new const CONFIG_NAME[] = "promocodes";

// Название SQL тэга в консоль / логи сервера.
//
// SQL tag name to console / server logs.
new const SQL_TAG[] = "[AmxxPromocodes]";

const PR_HANDLED = 0xB371;

new g_Cvars[CvarStruct], g_Forwards[ForwardStruct], Handle: g_hSqlConnection, Handle: g_hSqlTuple;

public plugin_precache() {
    CreateLangFile();
    CreateCvars();

    SqlTryConnect();

    CreateForwards();
}

public plugin_init() {
    register_plugin("[AMXX] Promocode System", "1.0.0", "ImmortalAmxx");

    register_clcmd(g_Cvars[CVAR_CMD_USE], "ClCmd_UsePromoCode");
    register_clcmd(g_Cvars[CVAR_CMD_ADD], "ClCmd_AddPromoCode");
}

public plugin_end() {
	if(g_hSqlTuple) 
		SQL_FreeHandle(g_hSqlTuple);
	
	if(g_hSqlConnection) 
		SQL_FreeHandle(g_hSqlConnection);
}

public ClCmd_UsePromoCode(UserId) {
    enum {
        Arg_Name = 1
    };

    new szPromoCodeName[256];
    read_argv(Arg_Name, szPromoCodeName, charsmax(szPromoCodeName));

    if(read_argc() < 2) {
        console_print(UserId, "%l", "CONSOLE_PRINT_USAGE");
        return PLUGIN_HANDLED;
    }

    trim(szPromoCodeName);
    remove_quotes(szPromoCodeName);

    new szQuery[1024], iData[2];
        
    formatex(szQuery, charsmax(szQuery),
        "SELECT * FROM `%s` WHERE `PromoName` = '%s';",
        g_Cvars[CVAR_SQL_TABLE], szPromoCodeName
    );

    iData[0] = SQL_USE_PROMOCODE;
    iData[1] = UserId;
    SQL_ThreadQuery(g_hSqlTuple, "Query_SqlHandler", szQuery, iData, sizeof(iData));

    return PLUGIN_HANDLED;
}

public ClCmd_AddPromoCode(UserId, LevelId, Cid) {
    if(g_Cvars[CVAR_ACCESS][0] && ~get_user_flags(UserId) & read_flags(g_Cvars[CVAR_ACCESS])) {
        console_print(UserId, "%l", "CONSOLE_PRINT_NO_ACCESS");
        return PLUGIN_HANDLED;
    }

    enum {
        Arg_Name = 1,
        Arg_Desc,
        Arg_MaxActivate
    };

    new szPromoCodeName[64], szPromoCodeDescription[256], szPromoCodeMaxActivate[16], iPromoMaxActivate, szQuery[1024], iData[1];

    read_argv(Arg_Name, szPromoCodeName, charsmax(szPromoCodeName));
    read_argv(Arg_Desc, szPromoCodeDescription, charsmax(szPromoCodeDescription));
    read_argv(Arg_MaxActivate, szPromoCodeMaxActivate, charsmax(szPromoCodeMaxActivate));

    if(read_argc() < 4) {
        console_print(UserId, "%l", "CONSOLE_PRINT_USAGE_ADD");
        return PLUGIN_HANDLED;
    }

    iPromoMaxActivate = str_to_num(szPromoCodeMaxActivate);

    trim(szPromoCodeName);
    trim(szPromoCodeDescription);

    remove_quotes(szPromoCodeName);
    remove_quotes(szPromoCodeDescription);

    formatex(szQuery, charsmax(szQuery),
        "REPLACE INTO `%s` (`PromoName`, `PromoDescription`, `PromoMaximumActivate`) VALUES ('%s', '%s', '%i');",
        g_Cvars[CVAR_SQL_TABLE], szPromoCodeName, szPromoCodeDescription, iPromoMaxActivate
    );

    iData[0] = SQL_ADD_PROMOCODE;
    SQL_ThreadQuery(g_hSqlTuple, "Query_SqlHandler", szQuery, iData, sizeof(iData));

    static iRet;
    ExecuteForward(g_Forwards[FORWARD_ADD], iRet, UserId, szPromoCodeName, szPromoCodeDescription, iPromoMaxActivate);

    return PLUGIN_HANDLED;
}

public SqlTryConnect() {
    new iError, szError[128];

    g_hSqlTuple = SQL_MakeDbTuple(g_Cvars[CVAR_SQL_HOST], g_Cvars[CVAR_SQL_USER], g_Cvars[CVAR_SQL_PASS], g_Cvars[CVAR_SQL_DB]);
    g_hSqlConnection = SQL_Connect(g_hSqlTuple, iError, szError, charsmax(szError));

    if(g_hSqlConnection == Empty_Handle) 
        set_fail_state("%L", LANG_SERVER, "SQL_CONNECT_ERROR", SQL_TAG, SQL_TAG, szError);
    else 
        log_amx("%s Подключение к базе данных прошло успешно!", SQL_TAG);

    SQL_SetCharset(g_hSqlTuple, "utf8");

    new szQuery[1024];
    formatex(szQuery, charsmax(szQuery),
        "CREATE TABLE IF NOT EXISTS `%s`\
        (\
            `PromoName` VARCHAR(64) NOT NULL,\
            `PromoDescription` VARCHAR(256) NOT NULL,\
            `PromoMaximumActivate` INT NOT NULL,\
            PRIMARY KEY(`PromoName`)\
        )\
        ENGINE = InnoDB DEFAULT CHARSET = utf8;",
        g_Cvars[CVAR_SQL_TABLE]
    );

    new iData[1];
    iData[0] = SQL_CREATE_TABLE;

    SQL_ThreadQuery(g_hSqlTuple, "Query_SqlHandler", szQuery, iData, sizeof(iData));
}

public Query_SqlHandler(iFailState, Handle:hQuery, szError[], iErrNum, iData[], iSize, Float:fQueueTime) {
    if(iFailState != TQUERY_SUCCESS) {
        log_amx("%L", LANG_SERVER, "SQL_QUERY_ERROR", SQL_TAG, SQL_TAG, szError);

        return;
    }

    switch(iData[0]) {
        case SQL_USE_PROMOCODE: {
            if(SQL_NumResults(hQuery)) {
                enum {
                    Read_Name,
                    Read_Desc,
                    Read_MaxUse
                };

                new UserId = iData[1], szPromoCodeName[64], szPromoCodeDescription[256], iMaxUse, szQuery[1024];

                static iRet;
                ExecuteForward(g_Forwards[FORWARD_USE_PRE], iRet, UserId, szPromoCodeName, szPromoCodeDescription, iMaxUse);

                if(iRet != PR_HANDLED) {
                    SQL_ReadResult(hQuery, Read_Name, szPromoCodeName, charsmax(szPromoCodeName));
                    SQL_ReadResult(hQuery, Read_Desc, szPromoCodeDescription, charsmax(szPromoCodeDescription));
                    iMaxUse = SQL_ReadResult(hQuery, Read_MaxUse);

                    if(iMaxUse > 0) {
                        formatex(szQuery, charsmax(szQuery), 
                            "UPDATE `%s` SET `PromoMaximumActivate` = `PromoMaximumActivate` - 1 WHERE `PromoName` = '%s';",
                            g_Cvars[CVAR_SQL_TABLE], szPromoCodeName
                        );

                        new iData[1];
                        iData[0] = SLQ_UPDATE_PROMOCODE;
                        SQL_ThreadQuery(g_hSqlTuple, "Query_SqlHandler", szQuery, iData, sizeof(iData));
                    }
                    else {
                        formatex(szQuery, charsmax(szQuery), 
                            "DELETE FROM `%s` WHERE `PromoName` = '%s';",
                            g_Cvars[CVAR_SQL_TABLE], szPromoCodeName
                        );

                        new iData[1];
                        iData[0] = SQL_DELETE_PROMOCODE;
                        SQL_ThreadQuery(g_hSqlTuple, "Query_SqlHandler", szQuery, iData, sizeof(iData));                    
                    }

                    ExecuteForward(g_Forwards[FORWARD_USE_POST], iRet, UserId, szPromoCodeName, szPromoCodeDescription, iMaxUse)
                }               
            }
        }
    }
}

CreateLangFile() {
    new szFileName[256];
    formatex(szFileName, charsmax(szFileName), "%s/%s", LANG_PATH, LANG_NAME);

    if(!file_exists(szFileName)) {
        write_file(szFileName, 
            "[ua]^n\
            CVAR_SQL_HOST = Хост від бази даних.^n\
            CVAR_SQL_USER = Ім'я користувача від бази данинх.^n\
            CVAR_SQL_PASS = Пароль від бази даних.^n\
            CVAR_SQL_DB = Найменування бази даних.^n\
            CVAR_SQL_TABLE = Найменування таблиці в базі даних.^n\
            CVAR_ACCESS = Флаг доступу для додавання промокоду.^n\
            CVAR_CMD_ADD = Команда для додавання промокоду.^n\
            CVAR_CMD_USE = Команда для використання промокоду.^n^n\
            SQL_CONNECT_ERROR = %s Не вадлось під'єднатись до бази даних.^^n%s Відповідь від сервера: %s^n\
            SQL_QUERY_ERROR = %s Помилка запиту.^^n%s Відповідь: %s^n^n\
            CONSOLE_PRINT_NO_ACCESS = Відказано в доступі.^n\
            CONSOLE_PRINT_USAGE = Використовуйте: команда <назва>^n\
            CONSOLE_PRINT_USAGE_ADD = Використовуйте: команда <назва> <опис> <кількість використань>^n\
            ^n\
            [ru]^n\
            CVAR_SQL_HOST = Хост от базы данных.^n\
            CVAR_SQL_USER = Имя пользователя от базы данных.^n\
            CVAR_SQL_PASS = Пароль от базы данных.^n\
            CVAR_SQL_DB = Название базы данных.^n\
            CVAR_SQL_TABLE = Название таблицы в базе данных.^n\
            CVAR_ACCESS = Флаг доступа для создания промокода.^n\
            CVAR_CMD_ADD = Команда для создания промокода.^n\            
            CVAR_CMD_USE = Команда для использования промокода.^n^n\        
            SQL_CONNECT_ERROR = %s Не удалось подключится к БД^^n%s Ответ от сервера: %s^n\
            SQL_QUERY_ERROR = %s Ошибка запроса!^^n%sОтвет:%s^n^n\
            CONSOLE_PRINT_NO_ACCESS = Отказано в доступе.^n\
            CONSOLE_PRINT_USAGE = Используйте: команда <название>^n\
            CONSOLE_PRINT_USAGE_ADD = Используйте: команда <название> <описание> <количество использований>^n\
            ^n\
            [en]^n\
            CVAR_SQL_HOST = Host from the database.^n\
            CVAR_SQL_USER = User name from the database.^n\
            CVAR_SQL_PASS = Password from the database.^n\
            CVAR_SQL_DB = Name of the database.^n\
            CVAR_SQL_TABLE = Name of the table in the database.^n\
            CVAR_ACCESS = Access flag for creating a promo code.^n\
            CVAR_CMD_ADD = Command to create a promo code.^n\          
            CVAR_CMD_USE = Command to use promo code.^n^n\        
            SQL_CONNECT_ERROR = %s Failed to connect to database^^n%s Server response: %s^n\
            SQL_QUERY_ERROR = %s Query Error!^^n%sResponse:%s^n^n\
            CONSOLE_PRINT_NO_ACCESS = Access denied.^n\
            CONSOLE_PRINT_USAGE = Use: command <name>^n\
            CONSOLE_PRINT_USAGE_ADD = Use: command <name> <description> <number of uses>"
        );
    }

    register_dictionary(LANG_NAME);
}

CreateCvars() {
    bind_pcvar_string(create_cvar("promo_sql_host", "localhost", FCVAR_PROTECTED, FMT_CVAR("CVAR_SQL_HOST")), g_Cvars[CVAR_SQL_HOST], charsmax(g_Cvars[CVAR_SQL_HOST]));
    bind_pcvar_string(create_cvar("promo_sql_user", "root", FCVAR_PROTECTED, FMT_CVAR("CVAR_SQL_USER")), g_Cvars[CVAR_SQL_USER], charsmax(g_Cvars[CVAR_SQL_USER]));
    bind_pcvar_string(create_cvar("promo_sql_password", "", FCVAR_PROTECTED, FMT_CVAR("CVAR_SQL_PASS")), g_Cvars[CVAR_SQL_PASS], charsmax(g_Cvars[CVAR_SQL_PASS]));
    bind_pcvar_string(create_cvar("promo_sql_db", "sborka", FCVAR_PROTECTED, FMT_CVAR("CVAR_SQL_DB")), g_Cvars[CVAR_SQL_DB], charsmax(g_Cvars[CVAR_SQL_DB]));
    bind_pcvar_string(create_cvar("promo_sql_table", "promocode", FCVAR_PROTECTED, FMT_CVAR("CVAR_SQL_TABLE")), g_Cvars[CVAR_SQL_TABLE], charsmax(g_Cvars[CVAR_SQL_TABLE]));

    bind_pcvar_string(create_cvar("promo_flag_access", "t", FCVAR_SERVER, FMT_CVAR("CVAR_ACCESS")), g_Cvars[CVAR_ACCESS], charsmax(g_Cvars[CVAR_ACCESS]));
    bind_pcvar_string(create_cvar("promo_cmd_add", "addpromo", FCVAR_SERVER, FMT_CVAR("CVAR_CMD_ADD")), g_Cvars[CVAR_CMD_ADD], charsmax(g_Cvars[CVAR_CMD_ADD]));
    bind_pcvar_string(create_cvar("promo_cmd_use", "promocode", FCVAR_SERVER, FMT_CVAR("CVAR_CMD_USE")), g_Cvars[CVAR_CMD_USE], charsmax(g_Cvars[CVAR_CMD_USE]));

    #if defined CONFIG_NAME
        AutoExecConfig(true, CONFIG_NAME);

        new szPath[PLATFORM_MAX_PATH];
        get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
        server_cmd("exec %s/plugins/%s.cfg", szPath, CONFIG_NAME);
        server_exec();
    #endif
}

CreateForwards() {
    g_Forwards[FORWARD_ADD] = CreateMultiForward("promocode_add_promo", ET_IGNORE, FP_CELL, FP_STRING, FP_STRING, FP_CELL);
    g_Forwards[FORWARD_USE_PRE] = CreateMultiForward("promocode_use_promo_pre", ET_STOP, FP_CELL, FP_STRING, FP_STRING, FP_CELL);
    g_Forwards[FORWARD_USE_POST] = CreateMultiForward("promocode_use_promo_post", ET_IGNORE, FP_CELL, FP_STRING, FP_STRING, FP_CELL);
}