CREATE OR REPLACE PACKAGE HTML_EMAIL AS
    PROCEDURE SEND(
        send_host IN VARCHAR2,
        send_port IN NUMBER DEFAULT 25,
        send_login IN VARCHAR2,
        send_password IN VARCHAR2,
        send_from IN VARCHAR2 DEFAULT NULL,
        send_to IN VARCHAR2,
        send_cc IN VARCHAR2 DEFAULT NULL,
        email_title IN VARCHAR2 DEFAULT '-',
        email_body IN CLOB DEFAULT '-',
        send_priority NUMBER DEFAULT 5
    );
    PROCEDURE SEND_MESSAGE(
        send_host IN VARCHAR2,
        send_port IN NUMBER DEFAULT 25,
        send_login IN VARCHAR2,
        send_password IN VARCHAR2,
        send_from IN VARCHAR2 DEFAULT NULL,
        send_to IN VARCHAR2,
        email_title IN VARCHAR2 DEFAULT '-',
        email_text IN CLOB DEFAULT '-'
    );
    PROCEDURE GENERATE(l_html_email IN CLOB, o_html_email OUT CLOB);
    PROCEDURE CLEAR_ATTACHMENTS;
    PROCEDURE ADD_ATTACHMENT(l_clob CLOB, l_attachment_name VARCHAR2);
    PROCEDURE ADD_ATTACHMENT(l_blob BLOB, l_attachment_name VARCHAR2);
    PROCEDURE ADD_ATTACHMENT(l_blob BLOB, l_attachment_name VARCHAR2, l_attachment_image VARCHAR2);
END HTML_EMAIL;
/

CREATE OR REPLACE PACKAGE BODY HTML_EMAIL AS
    g_doc DBMS_XMLDOM.DOMDOCUMENT;
    g_body_node DBMS_XMLDOM.DOMNODE;

    g_css_primary_color CLOB := '#2196F3';
    g_css_primary_contrast_color CLOB := '#ffffff';
    g_css_secondary_color CLOB := '#607d8b';
    g_css_background_email CLOB := 'background-color: #f5f5f5;';
    g_css_body_email CLOB := 'background-color: #ffffff;';
    g_css_default_width CLOB := '80%';
    g_css_font CLOB := ''||
            'line-height: 1.5em; '||
            'font-size: 1.1em; '||
            'font-family: ''Segoe UI'', Helvetica,Arial,sans-serif; ';
    g_css_global CLOB := 'margin: 0 0 0 0; padding: 0 0 0 0; ';
    g_css_fit CLOB := 'width:100%; ';
    g_css_reset CLOB := 'margin: 0 0 0 0; padding: 0 0 0 0; ';
    g_locale VARCHAR(5) := 'en-US';



    TYPE attachments_info IS RECORD (
        attach_id VARCHAR2(255),
        attach_name VARCHAR2(255),
        attach_base64 CLOB,
        attach_content BLOB
    );
    TYPE array_attachments IS TABLE OF attachments_info;
    attachments array_attachments := array_attachments();
    attachments_size NUMBER := 1;

    PROCEDURE CHECK_ATTACHMENTS
    IS
    BEGIN
        IF (NOT attachments.exists(attachments_size)) THEN
            attachments := array_attachments();
            attachments.extend(100);
        END IF;
    END;

    PROCEDURE CLEAR_ATTACHMENTS
    IS
    BEGIN
        CHECK_ATTACHMENTS();
        attachments.delete();
    END;

    PROCEDURE ADD_ATTACHMENT(l_blob BLOB, l_attachment_name VARCHAR2, l_attachment_image VARCHAR2, l_attachment_base64 CLOB)
    IS
    BEGIN
        CHECK_ATTACHMENTS();
        IF (LENGTH(l_blob) > 0) THEN
            attachments(attachments_size).attach_content := l_blob;
        END IF;
        IF (LENGTH(l_attachment_base64) > 0) THEN
            attachments(attachments_size).attach_base64 := l_attachment_base64;
        END IF;

        attachments(attachments_size).attach_name := l_attachment_name;
        attachments(attachments_size).attach_id := l_attachment_image;
        attachments_size := attachments_size + 1;
    END;

    PROCEDURE ADD_ATTACHMENT(l_blob BLOB, l_attachment_name VARCHAR2, l_attachment_image VARCHAR2)
    IS
    BEGIN
        ADD_ATTACHMENT(l_blob, l_attachment_name, NULL, NULL);
    END;

    PROCEDURE ADD_ATTACHMENT(l_clob CLOB, l_attachment_name VARCHAR2)
    IS
    BEGIN
        ADD_ATTACHMENT(NULL, l_attachment_name, NULL, l_clob);
    END;

    PROCEDURE ADD_ATTACHMENT(l_blob BLOB, l_attachment_name VARCHAR2)
    IS
    BEGIN
        ADD_ATTACHMENT(l_blob, l_attachment_name, NULL, NULL);
    END;

    FUNCTION GET_MESSAGE(l_name VARCHAR2, l_locale VARCHAR2)
    RETURN VARCHAR2 IS
        attr CLOB := '';
    BEGIN
        CASE l_locale
            WHEN 'en-US' THEN
                CASE l_name
                    WHEN 'AUTOMATIC_EMAIL' THEN
                        RETURN 'This is an automatic email sent by the system, please do not answer';
                ELSE RETURN ''; END CASE;
            WHEN 'pt-BR' THEN
                CASE l_name
                    WHEN 'AUTOMATIC_EMAIL' THEN
                        RETURN 'Este é um email automático enviado pelo sistema, favor não responder';
                ELSE RETURN ''; END CASE;
        ELSE RETURN ''; END CASE;
    END;

    FUNCTION GET_MESSAGE(l_name VARCHAR2)
    RETURN VARCHAR2 IS
    BEGIN
        RETURN GET_MESSAGE(l_name, g_locale);
    END;

    PROCEDURE SET_NODE_CONTENT(node DBMS_XMLDOM.DOMNODE, l_content CLOB)
    IS
        text_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        IF (l_content IS NOT NULL) THEN
            text_node := DBMS_XMLDOM.MAKENODE(DBMS_XMLDOM.CREATETEXTNODE(g_doc, l_content));
            text_node := DBMS_XMLDOM.APPENDCHILD(node, text_node);
        END IF;
    END;

    FUNCTION CREATE_NODE(l_name VARCHAR2, l_content CLOB)
    RETURN DBMS_XMLDOM.DOMNODE IS
        aux_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        aux_node := DBMS_XMLDOM.MAKENODE(DBMS_XMLDOM.CREATEELEMENT(g_doc, l_name));

        SET_NODE_CONTENT(aux_node, l_content);

        RETURN aux_node;
    END;
    FUNCTION CREATE_NODE(l_name VARCHAR2)
    RETURN DBMS_XMLDOM.DOMNODE IS
    BEGIN
        RETURN CREATE_NODE(l_name, null);
    END;

    FUNCTION APPEND_NODE(l_name VARCHAR2, node DBMS_XMLDOM.DOMNODE, l_content CLOB)
    RETURN DBMS_XMLDOM.DOMNODE IS
        aux_node DBMS_XMLDOM.DOMNODE;
        aux2_node DBMS_XMLDOM.DOMNODE;
        xd DBMS_XMLDOM.DOMNODE;
    BEGIN
        RETURN DBMS_XMLDOM.APPENDCHILD(node,
            CREATE_NODE(l_name, l_content)
        );
    END;

    FUNCTION APPEND_NODE(l_name VARCHAR2, node DBMS_XMLDOM.DOMNODE)
    RETURN DBMS_XMLDOM.DOMNODE IS
    BEGIN
        RETURN APPEND_NODE(l_name, node, '');
    END;

    FUNCTION APPEND_NODE(l_name VARCHAR2)
    RETURN DBMS_XMLDOM.DOMNODE IS
    BEGIN
        RETURN APPEND_NODE(l_name, g_body_node);
    END;

    FUNCTION PREPEND_NODE(l_name VARCHAR2, node DBMS_XMLDOM.DOMNODE, l_content CLOB)
    RETURN DBMS_XMLDOM.DOMNODE IS
        created_node DBMS_XMLDOM.DOMNODE;
        inserted_node DBMS_XMLDOM.DOMNODE;
        parent_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        parent_node := DBMS_XMLDOM.GETPARENTNODE(node);
        created_node := CREATE_NODE(l_name, l_content);
        inserted_node := DBMS_XMLDOM.INSERTBEFORE(parent_node, created_node, node);
        RETURN created_node;
    END;

    FUNCTION PREPEND_NODE(l_name VARCHAR2, node DBMS_XMLDOM.DOMNODE)
    RETURN DBMS_XMLDOM.DOMNODE IS
    BEGIN
        RETURN PREPEND_NODE(l_name, node, '');
    END;

    FUNCTION GET_NODE(l_name VARCHAR2)
    RETURN DBMS_XMLDOM.DOMNODE IS
    BEGIN
        RETURN DBMS_XMLDOM.ITEM(DBMS_XMLDOM.GETCHILDRENBYTAGNAME(DBMS_XMLDOM.GETDOCUMENTELEMENT(g_doc), l_name), 0);
    END;

    FUNCTION GET_LIST(node DBMS_XMLDOM.DOMNODE)
    RETURN DBMS_XMLDOM.DOMNODELIST IS
    BEGIN
        RETURN DBMS_XMLDOM.GETELEMENTSBYTAGNAME(DBMS_XMLDOM.MAKEELEMENT(node), '*');
    END;

    PROCEDURE REPLACE_NODE(to_replace DBMS_XMLDOM.DOMNODE, for_replace DBMS_XMLDOM.DOMNODE)
    IS
        aux1_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        aux1_node := DBMS_XMLDOM.REPLACECHILD(g_body_node, for_replace, to_replace);
    END REPLACE_NODE;

    PROCEDURE WRAP_NODE(to_wrap DBMS_XMLDOM.DOMNODE, wrap_in DBMS_XMLDOM.DOMNODE)
    IS
        node_list DBMS_XMLDOM.DOMNODELIST;
        aux1_node DBMS_XMLDOM.DOMNODE;
        node DBMS_XMLDOM.DOMNODE;
        len NUMBER;
    BEGIN
        node_list := DBMS_XMLDOM.GETCHILDNODES(to_wrap);
        len  := NVL(DBMS_XMLDOM.GETLENGTH(node_list), 1);
        FOR i IN 0 .. len - 1 LOOP
            node := DBMS_XMLDOM.ITEM(node_list, i);
            aux1_node := DBMS_XMLDOM.APPENDCHILD(wrap_in, node);
        END LOOP;
    END;

    PROCEDURE SET_ATTRIBUTE(node DBMS_XMLDOM.DOMNODE, attr_name VARCHAR2, attr_value VARCHAR2)
    IS
    BEGIN
        DBMS_XMLDOM.SETATTRIBUTE(DBMS_XMLDOM.MAKEELEMENT(node), attr_name, attr_value);
    END SET_ATTRIBUTE;

    FUNCTION GET_ATTRIBUTE(node DBMS_XMLDOM.DOMNODE, attr_name VARCHAR2)
    RETURN VARCHAR2 IS
    BEGIN
        RETURN DBMS_XMLDOM.GETATTRIBUTE(DBMS_XMLDOM.MAKEELEMENT(node), attr_name);
    END;

    PROCEDURE SET_STYLE(node DBMS_XMLDOM.DOMNODE, attr_value VARCHAR2)
    IS
    BEGIN
        SET_ATTRIBUTE(node, 'style', GET_ATTRIBUTE(node, 'style')||attr_value);
    END SET_STYLE;

    PROCEDURE END_TASKS_COMPONENTS(node DBMS_XMLDOM.DOMNODE)
    IS
        aux_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        aux_node := DBMS_XMLDOM.REMOVECHILD(g_body_node, node);
    END;


    PROCEDURE RESET_TABLE(node DBMS_XMLDOM.DOMNODE)
    IS
    BEGIN
        SET_ATTRIBUTE(node, 'cellpadding', '0');
        SET_ATTRIBUTE(node, 'cellspacing', '0');
        SET_ATTRIBUTE(node, 'border', '0');
        --SET_ATTRIBUTE(node, 'align', 'left');
        SET_STYLE(node, 'border-collapse:collapse; ');
    END;

    FUNCTION GET_FONTSIZE(l_size VARCHAR2)
    RETURN VARCHAR2 IS
        attr CLOB := '';
    BEGIN
        CASE l_size
            WHEN '1' THEN RETURN '12';
            WHEN '2' THEN RETURN '16';
            WHEN '3' THEN RETURN '18';
            WHEN '4' THEN RETURN '22';
            WHEN '5' THEN RETURN '26';
            WHEN '6' THEN RETURN '32';
        ELSE
            RETURN '12';
        END CASE;
    END;

    FUNCTION HAS_ATTR(node DBMS_XMLDOM.DOMNODE, attr_name VARCHAR2)
    RETURN BOOLEAN IS
        attr CLOB := '';
    BEGIN
        attr := GET_ATTRIBUTE(node, attr_name);
        IF (attr IS NOT NULL AND attr <> '') THEN
            RETURN TRUE;
        END IF;
        RETURN FALSE;
    END;

    PROCEDURE CHECK_ATTR(
        check_node DBMS_XMLDOM.DOMNODE,
        attr_check VARCHAR2,
        put_node DBMS_XMLDOM.DOMNODE,
        attr_name VARCHAR2,
        attr_put VARCHAR2
    )
    IS
        final_style VARCHAR2(100) := '';
        attr VARCHAR2(100) := '';
    BEGIN
        attr := GET_ATTRIBUTE(check_node, attr_check);
        IF (attr IS NOT NULL) THEN
            final_style := REPLACE(attr_put, '$attr', attr);
            IF( attr_name = 'style') THEN
                SET_STYLE(put_node, final_style);
            ELSE
                SET_ATTRIBUTE(put_node, attr_name, final_style);
            END IF;
        END IF;
    END;


    PROCEDURE CHECK_ATTR(
        check_node DBMS_XMLDOM.DOMNODE,
        attr_check VARCHAR2,
        put_node DBMS_XMLDOM.DOMNODE,
        attr_put VARCHAR2
    )
    IS
        final_style VARCHAR2(100) := '';
        attr VARCHAR2(100) := '';
    BEGIN
        CHECK_ATTR(check_node, attr_check, put_node, 'style', attr_put);
    END;

    PROCEDURE CHECK_ATTR_SIZE(check_node DBMS_XMLDOM.DOMNODE, put_node DBMS_XMLDOM.DOMNODE, put_attr VARCHAR2)
    IS
        attr_size VARCHAR(5);
    BEGIN
        attr_size := GET_ATTRIBUTE(check_node, 'size');
        IF (attr_size IS NULL OR attr_size = '') THEN
            attr_size := '1';
        END IF;
        SET_ATTRIBUTE(put_node, put_attr, attr_size);
    END;

    PROCEDURE CHECK_ATTR_COLORS(check_node DBMS_XMLDOM.DOMNODE, put_node DBMS_XMLDOM.DOMNODE)
    IS
    BEGIN
        CHECK_ATTR(check_node, 'background', put_node, 'background-color: $attr;');
        CHECK_ATTR(check_node, 'foreground', put_node, 'color: $attr;');
    END;

    /* COMPONENTS */
    PROCEDURE EMAIL_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        html_node DBMS_XMLDOM.DOMNODE;
        head_node DBMS_XMLDOM.DOMNODE;
        body_node DBMS_XMLDOM.DOMNODE;
        table_node DBMS_XMLDOM.DOMNODE;
        tbody_node DBMS_XMLDOM.DOMNODE;
        viewport_node DBMS_XMLDOM.DOMNODE;
        content_node DBMS_XMLDOM.DOMNODE;
        aux_node DBMS_XMLDOM.DOMNODE;
        attr_lang VARCHAR(6);
    BEGIN
        attr_lang := GET_ATTRIBUTE(node, 'lang');
        IF (attr_lang IS NOT NULL) THEN
            g_locale := attr_lang;
        END IF;
        
        html_node := PREPEND_NODE('html', node);
        head_node := APPEND_NODE('head', html_node);
        viewport_node := APPEND_NODE('meta', head_node);
        SET_ATTRIBUTE(viewport_node, 'name' , 'viewport');
        SET_ATTRIBUTE(viewport_node, 'content' , 'width=device-width');

        content_node := APPEND_NODE('meta', head_node);
        SET_ATTRIBUTE(content_node, 'http-equiv' , 'Content-Type');
        SET_ATTRIBUTE(content_node, 'content' , 'text/html; charset=UTF-8');

        body_node := APPEND_NODE('body', html_node);
        SET_STYLE(body_node, g_css_font||g_css_global);
        table_node := APPEND_NODE('table', body_node);

        SET_STYLE(table_node, g_css_background_email);
        CHECK_ATTR_COLORS(node, table_node);
        RESET_TABLE(table_node);
        SET_STYLE(table_node, g_css_fit);
        tbody_node := APPEND_NODE('tbody', table_node);
        SET_STYLE(tbody_node, 'display: block; ');
        WRAP_NODE(node, tbody_node);

        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE ROW_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        td_node DBMS_XMLDOM.DOMNODE;
        div_node DBMS_XMLDOM.DOMNODE;
        table_node DBMS_XMLDOM.DOMNODE;
        tr_node DBMS_XMLDOM.DOMNODE;
        trcorpo_node DBMS_XMLDOM.DOMNODE;
        css_linha VARCHAR2(60) := 'max-width: 100%; '||
            'margin:0 auto; '||
            'display:block; ';
    BEGIN
        tr_node := PREPEND_NODE('tr', node);
        SET_STYLE(tr_node, 'display: block; ');
        SET_STYLE(tr_node, g_css_reset);

        td_node := APPEND_NODE('td', tr_node);
        SET_STYLE(td_node, 'width:'||g_css_default_width||';');
        SET_STYLE(td_node, g_css_reset);

        div_node := APPEND_NODE('div', td_node);
        SET_STYLE(td_node, css_linha||g_css_body_email||GET_ATTRIBUTE(node, 'style'));


        table_node := APPEND_NODE('table', div_node);
        RESET_TABLE(table_node);
        SET_STYLE(table_node, g_css_fit);

        trcorpo_node := APPEND_NODE('tr', table_node);
        SET_STYLE(trcorpo_node, g_css_reset);

        WRAP_NODE(node, trcorpo_node);

        END_TASKS_COMPONENTS(node);
    END;


    PROCEDURE PADDING_COMPONENT(node DBMS_XMLDOM.DOMNODE, x NUMBER, y NUMBER)
    IS
        table_node DBMS_XMLDOM.DOMNODE;
        tr_node DBMS_XMLDOM.DOMNODE;
        td_node DBMS_XMLDOM.DOMNODE;
        css_padding VARCHAR2(60) := 'padding: '||y||'px '||x||'px; ';
    BEGIN
        table_node := PREPEND_NODE('table', node);
        RESET_TABLE(table_node);
        SET_STYLE(table_node, g_css_fit);

        tr_node := APPEND_NODE('tr', table_node);
        SET_STYLE(tr_node, g_css_fit);

        td_node := APPEND_NODE('td', tr_node);
        SET_STYLE(td_node, g_css_fit||css_padding||GET_ATTRIBUTE(node, 'style'));

        WRAP_NODE(node, td_node);
        END_TASKS_COMPONENTS(node);
    END;


    PROCEDURE COL_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        td_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        td_node := PREPEND_NODE('td', node);
        SET_STYLE(td_node, g_css_reset||g_css_font||g_css_body_email||GET_ATTRIBUTE(node, 'style'));
        CHECK_ATTR_SIZE(node, td_node, 'colspan');
        WRAP_NODE(node, td_node);

        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE IMAGE_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        img_node DBMS_XMLDOM.DOMNODE;
        attr_id VARCHAR2(80);
    BEGIN
        img_node := PREPEND_NODE('img', node);

        CHECK_ATTR(node, 'id', img_node, 'src', 'cid:$attr');
        CHECK_ATTR(node, 'location', img_node, 'src', '$attr');

        SET_STYLE(img_node, 'max-width: 100%; '||g_css_reset||GET_ATTRIBUTE(node, 'style'));
        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE TEXT_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        span_node DBMS_XMLDOM.DOMNODE;
        css_style CLOB;
        attr_aligment VARCHAR(8);
        attr_size VARCHAR(8);
    BEGIN
        span_node := PREPEND_NODE('span', node);
        CHECK_ATTR_COLORS(node, span_node);

        attr_aligment := UPPER(GET_ATTRIBUTE(node, 'alignment'));
        CASE attr_aligment
            WHEN 'JUSTIFY' THEN
                SET_STYLE(span_node, 'text-align: justify; display: block;');
            WHEN 'LEFT' THEN
                SET_STYLE(span_node, 'text-align: left;');
            WHEN 'RIGHT' THEN
                SET_STYLE(span_node, 'text-align: right;');
            WHEN 'CENTER' THEN
                SET_STYLE(span_node, 'text-align: center;');
        ELSE
            NULL;
        END CASE;

        CHECK_ATTR(node, 'bolder', span_node, 'style', 'font-weight: bold; ');
        CHECK_ATTR(node, 'italic', span_node, 'style', 'font-style: italic; ');
        CHECK_ATTR(node, 'underline', span_node, 'style', 'text-decoration: underline; ');

        attr_size := GET_ATTRIBUTE(node, 'size');
        IF (attr_size IS NOT NULL) THEN
            SET_STYLE(span_node, 'font-size: '||GET_FONTSIZE(attr_size)||'px;');
        END IF;

        WRAP_NODE(node, span_node);
        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE LABEL_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        table_node DBMS_XMLDOM.DOMNODE;
        tr_node DBMS_XMLDOM.DOMNODE;
        td_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        table_node := PREPEND_NODE('table', node);
        RESET_TABLE(table_node);

        tr_node := APPEND_NODE('tr', table_node);

        td_node := APPEND_NODE('td', tr_node);
        CHECK_ATTR_COLORS(node, td_node);
        SET_STYLE(td_node, 'padding: 4px 6px; border-radius: 3px;'||GET_ATTRIBUTE(node, 'style'));

        WRAP_NODE(node, td_node);
        END_TASKS_COMPONENTS(node);
    END;


    PROCEDURE BUTTON_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        exta_node DBMS_XMLDOM.DOMNODE;
        inta_node DBMS_XMLDOM.DOMNODE;
        table_node DBMS_XMLDOM.DOMNODE;
        tr_node DBMS_XMLDOM.DOMNODE;
        td_node DBMS_XMLDOM.DOMNODE;
        css_link VARCHAR(40) := 'cursor: pointer; text-decoration: none;';
        attr_location CLOB;
    BEGIN
        exta_node := PREPEND_NODE('a', node);
        SET_STYLE(exta_node, css_link);


        table_node := APPEND_NODE('table', exta_node);
        RESET_TABLE(table_node);
        SET_STYLE(table_node, 'background-color: '||g_css_primary_color||'; color: '||g_css_primary_contrast_color||';');
        CHECK_ATTR_COLORS(node, exta_node);

        tr_node := APPEND_NODE('tr', table_node);

        td_node := APPEND_NODE('td', tr_node);
        SET_STYLE(td_node, css_link);
        SET_STYLE(td_node, g_css_font||'padding: 10px;'||GET_ATTRIBUTE(node, 'style'));


        inta_node := APPEND_NODE('a', td_node);
        SET_STYLE(inta_node, css_link);
        SET_STYLE(inta_node, 'background-color: '||g_css_primary_color||'; color: '||g_css_primary_contrast_color||';');
        CHECK_ATTR_COLORS(node, inta_node);

        attr_location := GET_ATTRIBUTE(node, 'location');
        IF (attr_location IS NULL OR attr_location = '') THEN
            attr_location := '#';
        END IF;
        SET_ATTRIBUTE(exta_node, 'href', attr_location);
        SET_ATTRIBUTE(inta_node, 'href', attr_location);

        WRAP_NODE(node, inta_node);
        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE INFO_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        attr_type VARCHAR2(60);
        span_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        attr_type := GET_ATTRIBUTE(node, 'type');
        IF(attr_type IS NOT NULL) THEN
            span_node := PREPEND_NODE('span', node);
            SET_NODE_CONTENT(span_node, GET_MESSAGE(attr_type));

            SET_STYLE(span_node, 'font-size: 10px;');
            SET_STYLE(span_node, g_css_background_email);
            SET_STYLE(span_node, 'color: '||g_css_secondary_color||';');
            SET_STYLE(span_node, 'text-align: center;');
            CHECK_ATTR_COLORS(node, span_node);
            PADDING_COMPONENT(span_node, 20, 20);
            WRAP_NODE(node, span_node);
        END IF;
        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE LINK_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        a_node DBMS_XMLDOM.DOMNODE;
        attr_location VARCHAR2(255);
    BEGIN
        a_node := PREPEND_NODE('a', node);
        SET_STYLE(a_node, 'text-decoration: none; display: inline-block;'||GET_ATTRIBUTE(node, 'style'));
        attr_location := GET_ATTRIBUTE(node, 'location');
        IF (attr_location IS NULL OR attr_location = '') THEN
            attr_location := '#';
        END IF;
        SET_ATTRIBUTE(a_node, 'href', attr_location);
        CHECK_ATTR_COLORS(node, a_node);
        WRAP_NODE(node, a_node);
        REPLACE_NODE(node, a_node);
        END_TASKS_COMPONENTS(node);
    END;


    PROCEDURE HORIZONTALSPACE_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        attr_size VARCHAR2(3);
        span_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        attr_size := GET_ATTRIBUTE(node, 'size');
        IF(attr_size IS NULL) THEN
            attr_size := '1';
        END IF;
        span_node := PREPEND_NODE('span', node);
        SET_STYLE(span_node, 'padding: 1px '||attr_size||'px;');
        LABEL_COMPONENT(span_node);
        WRAP_NODE(node, span_node);
        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE TB_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        table_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        table_node := PREPEND_NODE('table', node);
        RESET_TABLE(table_node);
        SET_STYLE(table_node, g_css_fit);
        WRAP_NODE(node, table_node);
        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE TL_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        tr_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        tr_node := PREPEND_NODE('tr', node);
        SET_STYLE(tr_node, GET_ATTRIBUTE(node, 'style'));
        WRAP_NODE(node, tr_node);
        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE TC_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        td_node DBMS_XMLDOM.DOMNODE;
    BEGIN
        td_node := PREPEND_NODE('td', node);
        SET_STYLE(td_node, 'padding: 6px 8px;'||GET_ATTRIBUTE(node, 'style'));
        SET_STYLE(td_node, 'border-bottom: 1px solid #dee2e6;');
        CHECK_ATTR_SIZE(node, td_node, 'colspan');

        WRAP_NODE(node, td_node);
        END_TASKS_COMPONENTS(node);
    END;

    PROCEDURE TT_COMPONENT(node DBMS_XMLDOM.DOMNODE)
    IS
        td_node DBMS_XMLDOM.DOMNODE;
        attr_size VARCHAR(3);
    BEGIN
        td_node := PREPEND_NODE('td', node);

        SET_STYLE(td_node, 'font-weight: bold; ');
        CHECK_ATTR_SIZE(node, td_node, 'colspan');
        WRAP_NODE(node, td_node);
        TC_COMPONENT(td_node);
        END_TASKS_COMPONENTS(node);
    END;

    /* GENERATE */
    PROCEDURE GENERATE(l_html_email IN CLOB, o_html_email OUT CLOB)
    IS
        doc DBMS_XMLDOM.DOMDOCUMENT;
        node_list  DBMS_XMLDOM.DOMNODELIST;
        node   DBMS_XMLDOM.DOMNODE;
        len NUMBER;
        node_name VARCHAR2(25);
        v_html_email CLOB;
    BEGIN
        v_html_email := '<root><emailBody>'||l_html_email||'</emailBody></root>';
        doc := DBMS_XMLDOM.NEWDOMDOCUMENT(v_html_email);
        g_doc := doc;

        g_body_node := GET_NODE('emailBody');

        node_list := GET_LIST(g_body_node);
        len := DBMS_XMLDOM.GETLENGTH(node_list);

        FOR i IN 0 .. len - 1 LOOP
            node := DBMS_XMLDOM.ITEM(node_list, i);
            node_name := DBMS_XMLDOM.GETNODENAME(node);
            DBMS_OUTPUT.PUT_LINE('------------------------------- Scanning: '||node_name);
            CASE(UPPER(node_name))
                WHEN 'EMAIL' THEN EMAIL_COMPONENT(node);
                WHEN 'IMAGE' THEN IMAGE_COMPONENT(node);
                WHEN 'ROW' THEN ROW_COMPONENT(node);
                WHEN 'COL' THEN COL_COMPONENT(node);
                WHEN 'TEXT' THEN TEXT_COMPONENT(node);
                WHEN 'BUTTON' THEN BUTTON_COMPONENT(node);
                WHEN 'LABEL' THEN LABEL_COMPONENT(node);
                WHEN 'INFO' THEN INFO_COMPONENT(node);
                WHEN 'LINK' THEN LINK_COMPONENT(node);
                WHEN 'TB' THEN TB_COMPONENT(node);
                WHEN 'TL' THEN TL_COMPONENT(node);
                WHEN 'TC' THEN TC_COMPONENT(node);
                WHEN 'TT' THEN TT_COMPONENT(node);
                WHEN 'HORIZONTAL_SPACE' THEN HORIZONTALSPACE_COMPONENT(node);
                WHEN 'P1' THEN PADDING_COMPONENT(node, 15, 15);
                WHEN 'P2' THEN PADDING_COMPONENT(node, 30, 30);
                WHEN 'PX1' THEN PADDING_COMPONENT(node, 15, 0);
                WHEN 'PX2' THEN PADDING_COMPONENT(node, 30, 0);
            ELSE
                NULL;
            END CASE;
        END LOOP;
        SYS.DBMS_LOB.CREATETEMPORARY(o_html_email, TRUE);

        DBMS_XMLDOM.WRITETOCLOB(g_body_node, o_html_email);
        DBMS_XMLDOM.FREEDOCUMENT(doc);
    END;

    /* SENDERS */
    PROCEDURE SEND(
        send_host IN VARCHAR2,
        send_port IN NUMBER DEFAULT 25,
        send_login IN VARCHAR2,
        send_password IN VARCHAR2,
        send_from IN VARCHAR2 DEFAULT NULL,
        send_to IN VARCHAR2,
        send_cc IN VARCHAR2 DEFAULT NULL,
        email_title IN VARCHAR2 DEFAULT '-',
        email_body IN CLOB DEFAULT '-',
        send_priority number default 5
    ) IS
        mail_connection UTL_SMTP.CONNECTION;
        l_send_from VARCHAR2(255);
        output_email CLOB;
        l_boundary varchar2(32) := sys_guid();
        l_blob BLOB;
        l_clob CLOB;
        k NUMBER;
        j NUMBER;
        l_step NUMBER := 12000;
        
    BEGIN
        l_send_from := send_from;
        
        IF (l_send_from IS NULL) THEN
            l_send_from := send_login;
        END IF;

        /* COMPOSE EMAIL */
        GENERATE(email_body, output_email);

        /* SEND EMAIL */
        mail_connection := UTL_SMTP.OPEN_CONNECTION(send_host, send_port);
        
        begin
            UTL_SMTP.EHLO (mail_connection, send_host);
            exception
        when others then
            UTL_SMTP.HELO (mail_connection, send_host);
        end;    
        
        
        if(send_password is not null)then
            UTL_SMTP.COMMAND(mail_connection, 'AUTH LOGIN');
            UTL_SMTP.COMMAND(mail_connection,
            Utl_raw.cast_to_varchar2(Utl_encode.base64_encode(Utl_raw.cast_to_raw(send_login))));
            UTL_SMTP.COMMAND(mail_connection,
            Utl_raw.cast_to_varchar2(Utl_encode.base64_encode(Utl_raw.cast_to_raw(send_password))));
        end if;
        
        
        UTL_SMTP.MAIL(mail_connection, ('<' || send_login || '>'));
        FOR EMAIL IN (SELECT REGEXP_SUBSTR(send_to,'[^;,]+', 1, LEVEL) ENDERECO FROM DUAL
            CONNECT BY REGEXP_SUBSTR(send_to, '[^;,]+', 1, LEVEL) IS NOT NULL)
        LOOP
            UTL_SMTP.RCPT(mail_connection, ('<' || TRIM(EMAIL.ENDERECO) || '>'));
        END LOOP;


        UTL_SMTP.OPEN_DATA(mail_connection);
        UTL_SMTP.WRITE_DATA( mail_connection, 'Date : '|| to_char(systimestamp, 'Dy, dd Mon yyyy hh24:mi:ss tzhtzm','NLS_DATE_LANGUAGE=American') || utl_tcp.CRLF );
        UTL_SMTP.WRITE_DATA( mail_connection, 'From: ' || l_send_from || UTL_TCP.CRLF );
        UTL_SMTP.WRITE_DATA( mail_connection, 'Reply-to: ' || l_send_from || UTL_TCP.CRLF );
        UTL_SMTP.WRITE_DATA( mail_connection, 'To: ' || send_to || UTL_TCP.CRLF );
        UTL_SMTP.WRITE_DATA( mail_connection, 'X-Priority: ' || send_priority || utl_tcp.CRLF);
        UTL_SMTP.WRITE_DATA( mail_connection,  'X-MSMail-Priority: Hight' || utl_tcp.CRLF);

        
        UTL_SMTP.WRITE_DATA( mail_connection, 'Subject: =?ISO-8859-1?Q?' ||
            UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.QUOTED_PRINTABLE_ENCODE(UTL_RAW.CAST_TO_RAW(email_title))) ||
            '?=' || UTL_TCP.CRLF);
            
        UTL_SMTP.WRITE_DATA( mail_connection, 'MIME-Version: 1.0' || UTL_TCP.CRLF );

        UTL_SMTP.WRITE_DATA( mail_connection, 'Content-Type: multipart/mixed; ' || UTL_TCP.CRLF );
        UTL_SMTP.WRITE_DATA( mail_connection, ' boundary= "' || l_boundary || '"' || UTL_TCP.CRLF );
        UTL_SMTP.WRITE_DATA( mail_connection, UTL_TCP.CRLF );
        
        
        -- Body
        UTL_SMTP.WRITE_DATA(mail_connection, '--' || l_boundary || UTL_TCP.CRLF );
        UTL_SMTP.WRITE_DATA(mail_connection, 'Content-Type: text/html;charset=ISO-8859-1' || UTL_TCP.CRLF );
        UTL_SMTP.WRITE_DATA(mail_connection, 'Content-Transfer-Encoding: quoted-printable '|| UTL_TCP.CRLF);
        UTL_SMTP.WRITE_DATA(mail_connection, UTL_TCP.CRLF );

        j  := 1;
        k := 4000;
        WHILE j < SYS.DBMS_LOB.GETLENGTH(output_email) LOOP
            UTL_SMTP.WRITE_RAW_DATA(mail_connection, UTL_ENCODE.QUOTED_PRINTABLE_ENCODE(UTL_RAW.CAST_TO_RAW(SYS.DBMS_LOB.SUBSTR(output_email,k,j))));
            j  := j + k ;
            k := LEAST(1900, SYS.DBMS_LOB.GETLENGTH(output_email) - k);
        END LOOP;

        UTL_SMTP.WRITE_DATA(mail_connection, UTL_TCP.CRLF);
        -- Attachments
        FOR i in 1..attachments_size LOOP
            IF (attachments.exists(i) AND attachments(i).attach_name IS NOT NULL) THEN

                UTL_SMTP.write_data(mail_connection, '--' || l_boundary || UTL_TCP.crlf);
                UTL_SMTP.write_data(mail_connection, 'Content-Type: application/octet-stream; name="' || LOWER(attachments(i).attach_name) || '"' || UTL_TCP.crlf);
                UTL_SMTP.write_data(mail_connection, 'Content-Transfer-Encoding: base64' || UTL_TCP.crlf);
                UTL_SMTP.write_data(mail_connection, 'Content-Disposition: attachment; filename="' || LOWER(attachments(i).attach_name) || '"' || UTL_TCP.crlf || UTL_TCP.crlf);

                IF (attachments(i).attach_id IS NOT NULL) THEN
                    UTL_SMTP.WRITE_DATA(mail_connection, 'X-Attachment-Id: '||attachments(i).attach_id || UTL_TCP.CRLF );
                    UTL_SMTP.WRITE_DATA(mail_connection, 'Content-ID: <'||attachments(i).attach_id||'>' || UTL_TCP.CRLF );
                END IF;

               IF (attachments(i).attach_base64 IS NOT NULL) THEN
                    l_clob := attachments(i).attach_base64;
                    FOR i IN 0 .. TRUNC((SYS.DBMS_LOB.GETLENGTH(l_clob) - 1 )/l_step) LOOP
                      UTL_SMTP.write_data(mail_connection, SYS.DBMS_LOB.SUBSTR(l_clob, l_step, i * l_step + 1));
                    END LOOP;
                    UTL_SMTP.WRITE_DATA(mail_connection, UTL_TCP.CRLF || UTL_TCP.CRLF);
                ELSIF (attachments(i).attach_content IS NOT NULL) THEN
                    l_blob := attachments(i).attach_content;
                    FOR i IN 0 .. TRUNC((SYS.DBMS_LOB.GETLENGTH(l_blob) - 1 )/l_step) LOOP
                      UTL_SMTP.write_data(mail_connection, UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_ENCODE(SYS.DBMS_LOB.SUBSTR(l_blob, l_step, i * l_step + 1))));
                    END LOOP;
                    UTL_SMTP.WRITE_DATA(mail_connection, UTL_TCP.CRLF || UTL_TCP.CRLF);
                END IF;
                UTL_SMTP.WRITE_DATA(mail_connection, UTL_TCP.CRLF );
            END IF;
        END LOOP;
        UTL_SMTP.WRITE_DATA( mail_connection, '--' || l_boundary || '--' || UTL_TCP.CRLF );
        UTL_SMTP.WRITE_DATA( mail_connection, UTL_TCP.CRLF || '.' || UTL_TCP.CRLF );

        UTL_SMTP.CLOSE_DATA(mail_connection);
        UTL_SMTP.QUIT( mail_connection );


        DBMS_OUTPUT.PUT_LINE('send_host='||send_host);
        DBMS_OUTPUT.PUT_LINE('send_port='||send_port);
        DBMS_OUTPUT.PUT_LINE('send_login='||send_login);
        DBMS_OUTPUT.PUT_LINE('send_password='||send_password);
        DBMS_OUTPUT.PUT_LINE('send_from='||l_send_from);
        DBMS_OUTPUT.PUT_LINE('send_to='||send_to);
        DBMS_OUTPUT.PUT_LINE('email_title='||email_title);
      
    Exception
    WHEN OTHERS THEN
       utl_smtp.quit (mail_connection);        
    END;

    PROCEDURE SEND_MESSAGE(
        send_host IN VARCHAR2,
        send_port IN NUMBER DEFAULT 25,
        send_login IN VARCHAR2,
        send_password IN VARCHAR2,
        send_from IN VARCHAR2 DEFAULT NULL,
        send_to IN VARCHAR2,
        email_title IN VARCHAR2 DEFAULT '-',
        email_text IN CLOB DEFAULT '-'
    ) IS
        email_body CLOB;
    BEGIN
        email_body := '<email>
            <row>
                <col>
                    <text aligment="justify">'||email_text||'</text>
                </col>
            </row>
        </email>';
        SEND(
            send_host=>send_host,
            send_port=>send_port,
            send_login=>send_login,
            send_password=>send_password,
            send_from=>send_from,
            send_to=>send_to,
            email_title=>email_title,
            email_body=>email_body
        );
    END;
END HTML_EMAIL;
/
