CREATE TABLE seen (`sha1` VARCHAR(40), `body` TEXT, `first_seen` DATETIME, `last_seen` DATETIME, `order` UNSIGNED INT, `prefix` TEXT, `suffix` TEXT, PRIMARY KEY (`sha1`));

CREATE TABLE runlog (`program` VARCHAR(80), `finished` DATETIME, PRIMARY KEY (`program`));
INSERT INTO runlog(`program`) VALUES('collect-text-diff.pl');
INSERT INTO runlog(`program`) VALUES('collect-html-diff.pl');
INSERT INTO runlog(`program`) VALUES('plurk-new-entries.pl');
INSERT INTO runlog(`program`) VALUES('telegram-new-entries.pl');
