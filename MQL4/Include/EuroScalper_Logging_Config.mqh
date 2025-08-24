// EuroScalper_Logging_Config.mqh
#property strict
extern bool ES_Log_Enable     = true;
extern int  ES_Log_Level      = 3;   // 0=ERROR,1=WARN,2=INFO,3=DEBUG,4=TRACE (reserved)
extern int  ES_Log_FlushEvery = 1;   // flush after each write when >0
extern int  ES_Log_MaxFileMB  = 50;  // (reserved for future rotation)
