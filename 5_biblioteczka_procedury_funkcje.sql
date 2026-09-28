CREATE OR REPLACE PACKAGE BODY ZARZADZANIE_BIBLIOTECZKA AS

    PROCEDURE DODAJ_KSIAZKE(p_tytul VARCHAR2, p_imie_autora VARCHAR2, p_nazwisko_autora VARCHAR2, p_id_szafki INT DEFAULT NULL) IS
        v_autor_ref REF AUTOR_TYP;
        v_szafka_ref REF SZAFKA_TYP := NULL;
    BEGIN
        BEGIN
            SELECT REF(a) INTO v_autor_ref FROM AUTOR a WHERE IMIE = p_imie_autora AND NAZWISKO = p_nazwisko_autora;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Blad: Podany autor nie istnieje.');
        END;
        
        IF p_id_szafki IS NOT NULL THEN
            BEGIN
                SELECT REF(s) INTO v_szafka_ref FROM SZAFKA s WHERE SZAFKA_ID = p_id_szafki;
            EXCEPTION WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002, 'Blad: Podana szafka nie istnieje.');
            END;
        END IF;

        INSERT INTO KSIAZKA (TYTUL, AUTOR, SZAFKA, STRONY)
        VALUES (p_tytul, v_autor_ref, v_szafka_ref, STRONA_TAB());
        DBMS_OUTPUT.PUT_LINE('Dodano ksiazke: ' || p_tytul);
    END;

    PROCEDURE USUN_KSIAZKE(p_tytul VARCHAR2) IS
    BEGIN
        DELETE FROM KSIAZKA WHERE TYTUL = p_tytul;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Ksiazka nie istnieje.');
        END IF;
        DBMS_OUTPUT.PUT_LINE('Usunieto ksiazke: ' || p_tytul);
    END;

    PROCEDURE MODYFIKUJ_DANE_KSIAZKI(p_stary_tytul VARCHAR2, p_nowy_tytul VARCHAR2 DEFAULT NULL, p_nowe_imie_autora VARCHAR2 DEFAULT NULL, p_nowe_nazwisko_autora VARCHAR2 DEFAULT NULL) IS
        v_nowy_autor_ref REF AUTOR_TYP := NULL;
    BEGIN
        IF p_nowe_imie_autora IS NOT NULL AND p_nowe_nazwisko_autora IS NOT NULL THEN
            BEGIN
                SELECT REF(a) INTO v_nowy_autor_ref FROM AUTOR a WHERE IMIE = p_nowe_imie_autora AND NAZWISKO = p_nowe_nazwisko_autora;
            EXCEPTION WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Blad: Nowy autor nie istnieje.');
            END;
        END IF;

        UPDATE KSIAZKA
        SET TYTUL = NVL(p_nowy_tytul, TYTUL),
            AUTOR = NVL(v_nowy_autor_ref, AUTOR) 
        WHERE TYTUL = p_stary_tytul;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Ksiazka ' || p_stary_tytul || ' nie istnieje.');
        END IF;
    END;

    PROCEDURE ZMIEN_SZAFKE_KSIAZKI(p_tytul VARCHAR2, p_id_nowej_szafki INT DEFAULT NULL) IS
        v_szafka_ref REF SZAFKA_TYP := NULL;
    BEGIN
        IF p_id_nowej_szafki IS NOT NULL THEN
            SELECT REF(s) INTO v_szafka_ref FROM SZAFKA s WHERE SZAFKA_ID = p_id_nowej_szafki;
        END IF;
        
        UPDATE KSIAZKA SET SZAFKA = v_szafka_ref WHERE TYTUL = p_tytul;
    END;

    PROCEDURE DODAJ_STRONE(p_tytul_ksiazki VARCHAR2, p_tresc VARCHAR2, p_numer_strony NUMBER) IS
        v_ksiazka_id INT;
        v_czy_strona_istnieje NUMBER;
    BEGIN
        SELECT KSIAZKA_ID INTO v_ksiazka_id FROM KSIAZKA WHERE TYTUL = p_tytul_ksiazki;
        
        SELECT COUNT(*) INTO v_czy_strona_istnieje 
        FROM TABLE(SELECT STRONY FROM KSIAZKA WHERE KSIAZKA_ID = v_ksiazka_id) 
        WHERE NUMER_STRONY = p_numer_strony;
        
        IF v_czy_strona_istnieje > 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Strona o tym numerze juz istnieje w tej ksiazce!');
        END IF;

        INSERT INTO TABLE(SELECT STRONY FROM KSIAZKA WHERE KSIAZKA_ID = v_ksiazka_id)
        VALUES (STRONA_TYP(seq_strona_id.NEXTVAL, p_tresc, p_numer_strony));
    EXCEPTION WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'Podana ksiazka nie istnieje.');
    END;

    PROCEDURE USUN_STRONE(p_tytul_ksiazki VARCHAR2, p_numer_strony NUMBER) IS
    BEGIN
        DELETE FROM TABLE(SELECT STRONY FROM KSIAZKA WHERE TYTUL = p_tytul_ksiazki)
        WHERE NUMER_STRONY = p_numer_strony;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Brak strony lub ksiazki.');
        END IF;
    END;


    PROCEDURE DODAJ_GATUNEK(p_nazwa VARCHAR2) IS BEGIN INSERT INTO GATUNEK (NAZWA_GATUNKU) VALUES (p_nazwa); END;
    PROCEDURE USUN_GATUNEK(p_nazwa VARCHAR2) IS BEGIN DELETE FROM GATUNEK WHERE NAZWA_GATUNKU = p_nazwa; END;

    PROCEDURE DODAJ_KSIAZCE_GATUNEK(p_tytul_ksiazki VARCHAR2, p_nazwa_gatunku VARCHAR2) IS
        v_ksiazka_id INT;
        v_gatunek_id INT;
        v_ile_gatunkow NUMBER;
    BEGIN
        SELECT KSIAZKA_ID INTO v_ksiazka_id FROM KSIAZKA WHERE TYTUL = p_tytul_ksiazki;
        SELECT GATUNEK_ID INTO v_gatunek_id FROM GATUNEK WHERE NAZWA_GATUNKU = p_nazwa_gatunku;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20007, 'Blad: Podana ksiazka lub gatunek nie istnieje!');
        END;
        
        SELECT COUNT(*) INTO v_ile_gatunkow FROM KSIAZKA_GATUNEK WHERE KSIAZKA_ID = v_ksiazka_id;
        IF v_ile_gatunkow >= 3 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Ksiazka moze miec maksymalnie 3 gatunki!');
        END IF;

        INSERT INTO KSIAZKA_GATUNEK (KSIAZKA_ID, GATUNEK_ID) VALUES (v_ksiazka_id, v_gatunek_id);
    END;

    PROCEDURE USUN_KSIAZCE_GATUNEK(p_tytul_ksiazki VARCHAR2, p_nazwa_gatunku VARCHAR2) IS
    BEGIN
        DELETE FROM KSIAZKA_GATUNEK 
        WHERE KSIAZKA_ID = (SELECT KSIAZKA_ID FROM KSIAZKA WHERE TYTUL = p_tytul_ksiazki)
          AND GATUNEK_ID = (SELECT GATUNEK_ID FROM GATUNEK WHERE NAZWA_GATUNKU = p_nazwa_gatunku);
          
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20008, 'Nie usunieto wpisu (brak powiazania, zly tytul lub gatunek).');
        END IF;  
    END;

    PROCEDURE DODAJ_AUTORA(p_imie VARCHAR2, p_nazwisko VARCHAR2) IS BEGIN INSERT INTO AUTOR (IMIE, NAZWISKO) VALUES (p_imie, p_nazwisko); END;
    PROCEDURE USUN_AUTORA(p_imie VARCHAR2, p_nazwisko VARCHAR2) IS
    v_czy_ma_ksiazki NUMBER;
    v_autor_ref REF AUTOR_TYP;
    BEGIN
        BEGIN
            SELECT REF(a) INTO v_autor_ref FROM AUTOR a WHERE IMIE = p_imie AND NAZWISKO = p_nazwisko;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20013, 'Autor nie istnieje.');
        END;
    
        SELECT COUNT(*) INTO v_czy_ma_ksiazki FROM KSIAZKA WHERE AUTOR = v_autor_ref;
        
        IF v_czy_ma_ksiazki > 0 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Nie mozesz usunac autora! Posiada on przypisane ksiazki w systemie.');
        END IF;
        
        DELETE FROM AUTOR WHERE IMIE = p_imie AND NAZWISKO = p_nazwisko;
    END;
    
    PROCEDURE DODAJ_SZAFKE(p_max_pojemnosc NUMBER) IS BEGIN INSERT INTO SZAFKA (MAX_POJEMNOSC, AKTUALNA_LICZBA_KSIAZEK) VALUES (p_max_pojemnosc, 0); END;
    PROCEDURE USUN_SZAFKE(p_id_szafki INT) IS
    v_liczba_ksiazek NUMBER;
    BEGIN
        BEGIN
            SELECT AKTUALNA_LICZBA_KSIAZEK INTO v_liczba_ksiazek 
            FROM SZAFKA WHERE SZAFKA_ID = p_id_szafki;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011, 'Szafka o podanym ID nie istnieje.');
        END;
        
        IF v_liczba_ksiazek > 0 THEN
            RAISE_APPLICATION_ERROR(-20012, 'Nie mozesz usunac szafki, na ktorej leza ksiazki! Najpierw zdejmij z niej: ' || v_liczba_ksiazek || ' szt.');
        END IF;
    
        DELETE FROM SZAFKA WHERE SZAFKA_ID = p_id_szafki;
    END;


    FUNCTION ILE_STRON_MA_KSIAZKA(p_tytul VARCHAR2) RETURN NUMBER IS
        v_wynik NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_wynik 
        FROM TABLE(SELECT STRONY FROM KSIAZKA WHERE TYTUL = p_tytul);
        RETURN v_wynik;
    END;

END ZARZADZANIE_BIBLIOTECZKA;
/

CREATE OR REPLACE PACKAGE BODY WYSWIETLANIE AS

    PROCEDURE WYSWIETL_WSZYSTKIE_KSIAZKI_Z_SZAFKI(p_id_szafki INT) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('KSIAZKI NA SZAFCE NR: ' || p_id_szafki);
        
        FOR rec IN (
            SELECT TYTUL, DEREF(AUTOR).IMIE AS IMIE, DEREF(AUTOR).NAZWISKO AS NAZWISKO
            FROM KSIAZKA k 
            WHERE DEREF(k.SZAFKA).SZAFKA_ID = p_id_szafki
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('- ' || rec.TYTUL || ' (' || rec.IMIE || ' ' || rec.NAZWISKO || ')');
        END LOOP;
    END;

    PROCEDURE WYSWIETL_SZCZEGOLY_KSIAZKI(p_tytul VARCHAR2) IS
        v_ksiazka_id INT;
        v_imie VARCHAR2(100);
        v_nazwisko VARCHAR2(100);
        v_id_szafki INT;
        v_liczba_stron NUMBER;
    BEGIN
        SELECT KSIAZKA_ID, DEREF(AUTOR).IMIE, DEREF(AUTOR).NAZWISKO, DEREF(SZAFKA).SZAFKA_ID
        INTO v_ksiazka_id, v_imie, v_nazwisko, v_id_szafki
        FROM KSIAZKA k WHERE TYTUL = p_tytul;
        
        v_liczba_stron := ZARZADZANIE_BIBLIOTECZKA.ILE_STRON_MA_KSIAZKA(p_tytul);
        
        DBMS_OUTPUT.PUT_LINE('SZCZEGOLY KSIAZKI');
        DBMS_OUTPUT.PUT_LINE('Tytul: ' || p_tytul);
        DBMS_OUTPUT.PUT_LINE('Autor: ' || v_imie || ' ' || v_nazwisko);
        DBMS_OUTPUT.PUT_LINE('Szafka: ' || NVL(TO_CHAR(v_id_szafki), 'Brak (nie przypisano)'));
        DBMS_OUTPUT.PUT_LINE('Zapisanych stron: ' || v_liczba_stron);
        
    EXCEPTION WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Ksiazka ' || p_tytul || ' nie istnieje w systemie.');
    END;

    PROCEDURE WYSWIETL_KSIAZKI_AUTORA(p_imie VARCHAR2, p_nazwisko VARCHAR2) IS
        v_licznik NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('KSIAZKI AUTORA: ' || p_imie || ' ' || p_nazwisko);
        
        FOR rec IN (
            SELECT TYTUL FROM KSIAZKA k
            WHERE DEREF(k.AUTOR).IMIE = p_imie AND DEREF(k.AUTOR).NAZWISKO = p_nazwisko
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('- ' || rec.TYTUL);
            v_licznik := v_licznik + 1;
        END LOOP;
        
        IF v_licznik = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Brak ksiazek tego autora.');
        END IF;
    END;

END WYSWIETLANIE;
/