use DatabaseName
GO
BACKUP MASTER KEY TO FILE = '\\server\folder\Exported_Master_Key.key' 
    ENCRYPTION BY PASSWORD = 'EncryptionPassword';   
GO  

use DatabaseName
GO

RESTORE MASTER KEY   
    FROM FILE = '\\server\folder\Exported_Master_Key.key' 
    DECRYPTION BY PASSWORD = 'EncryptionPassword'   
    ENCRYPTION BY PASSWORD = 'AnotherPassword';  
GO  

-- Drop, if needed
-- DROP MASTER KEY

-- Certify key with database
OPEN MASTER KEY DECRYPTION BY PASSWORD = 'AnotherPassword'
ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY
CLOSE MASTER KEY
GO

/* Check for existence of master key
IF (select Count(*) from sys.symmetric_keys where name like '%DatabaseMasterKey%') = 0
 BEGIN
 CREATE master key Encryption by password = 'passwordhere';
 END
*/