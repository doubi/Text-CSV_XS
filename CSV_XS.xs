/*  Copyright (c) 2007-2007 H.Merijn Brand.  All rights reserved.
 *  Copyright (c) 1998-2001 Jochen Wiedmann. All rights reserved.
 *  This program is free software; you can redistribute it and/or
 *  modify it under the same terms as Perl itself.
 */

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include "ppport.h"

#define MAINT_DEBUG	0
#define ALLOW_ALLOW	1

#define BUFFER_SIZE	1024

#define CSV_XS_TYPE_PV	0
#define CSV_XS_TYPE_IV	1
#define CSV_XS_TYPE_NV	2

/* Keep in sync with .pm! */
#define CACHE_ID_quote_char		0
#define CACHE_ID_escape_char		1
#define CACHE_ID_sep_char		2
#define CACHE_ID_binary			3
#define CACHE_ID_keep_meta_info		4
#define CACHE_ID_alwasy_quote		5
#define CACHE_ID_allow_loose_quotes	6
#define CACHE_ID_allow_loose_escapes	7
#define CACHE_ID_allow_whitespace	8
#define CACHE_ID_allow_double_quoted	9
#define CACHE_ID_eol			10
#define CACHE_ID_eol_len		18
#define CACHE_ID_eol_is_cr		19
#define CACHE_ID_has_types		20
#define CACHE_ID_verbatim		21

#define CSV_FLAGS_QUO	0x0001
#define CSV_FLAGS_BIN	0x0002
#define CSV_FLAGS_EIF	0x0004

#define CH_TAB		'\011'
#define CH_NL		'\012'
#define CH_CR		'\015'
#define CH_SPACE	'\040'
#define CH_DEL		'\177'

#define useIO_EOF	0x10

#define unless(expr)	if (!(expr))

#define CSV_XS_SELF					\
    if (!self || !SvOK (self) || !SvROK (self) ||	\
	 SvTYPE (SvRV (self)) != SVt_PVHV)		\
        croak ("self is not a hash ref");		\
    hv = (HV*)SvRV (self)

#define	byte	unsigned char
typedef struct {
    byte	 quote_char;
    byte	 escape_char;
    byte	 sep_char;
    byte	 binary;

    byte	 keep_meta_info;
    byte	 alwasy_quote;
    byte	 useIO;		/* Also used to indicate EOF */
    byte	 eol_is_cr;

#if ALLOW_ALLOW
    byte	 allow_loose_quotes;
    byte	 allow_loose_escapes;
    byte	 allow_whitespace;
    byte	 allow_double_quoted;

    byte	 verbatim;
    byte	 reserved1;
    byte	 reserved2;
    byte	 reserved3;
#endif

    byte	*cache;

    HV*		 self;

    char	*eol;
    STRLEN	 eol_len;
    char	*types;
    STRLEN	 types_len;

    char	*bptr;
    SV		*tmp;
    STRLEN	 size;
    STRLEN	 used;
    char	 buffer[BUFFER_SIZE];
    } csv_t;

#define bool_opt(o) \
    (((svp = hv_fetch (self, o, strlen (o), 0)) && *svp) ? SvTRUE (*svp) : 0)

typedef struct {
    int   xs_errno;
    char *xs_errstr;
    } xs_error_t;
xs_error_t xs_errors[] =  {

    /* Generic errors */
    { 1001, "sep_char is equal to quote_char or escape_char"			},

    /* Parse errors */
    { 2010, "ECR - QUO char inside quotes followed by CR not part of EOL"	},
    { 2011, "ECR - Characters after end of quoted field"			},
    { 2012, "EOF - End of data in parsing input stream"				},

    /*  EIQ - Error Inside Quotes */
    { 2021, "EIQ - NL char inside quotes, binary off"				},
    { 2022, "EIQ - CR char inside quotes, binary off"				},
    { 2023, "EIQ - QUO ..."							},
    { 2024, "EIQ - EOF cannot be escaped, not even inside quotes"		},
    { 2025, "EIQ - Loose unescaped escape"					},
    { 2026, "EIQ - Binary character inside quoted field, binary off"		},
    { 2027, "EIQ - Quoted field not terminated"					},

    /* EIF - Error Inside Field */
    { 2030, "EIF - NL char inside unquoted verbatim, binary off"		},
    { 2031, "EIF - CR char is first char of field, not part of EOL"		},
    { 2032, "EIF - CR char inside unquoted, not part of EOL"			},
    { 2033, "EIF - QUO, QUO != ESC, binary off"					},
    { 2034, "EIF - Loose unescaped quote"					},
    { 2035, "EIF - Escaped EOF in unquoted field"				},
    { 2036, "EIF - ESC error"							},
    { 2037, "EIF - Binary character in unquoted field, binary off"		},

    /* Combine errors */
    { 2110, "ECB - Binary character in Combine, binary off"			},

    {    0, "" },
    };

static void SetDiag (csv_t *csv, int xse)
{
    int   i = 0;
    SV   *err;

    while (xs_errors[i].xs_errno && xs_errors[i].xs_errno != xse) i++;
    if ((err = newSVpv (xs_errors[i].xs_errstr, 0))) {
	sv_upgrade (err, SVt_PVIV);
	SvIV_set (err, xse);
	SvIOK_on (err);
	hv_store (csv->self, "_ERROR_DIAG", 11, err, 0);
	}
    } /* SetDiag */

static void SetupCsv (csv_t *csv, HV *self)
{
    SV	       **svp;
    STRLEN	 len;
    char	*ptr;

    csv->self  = self;

    if ((svp = hv_fetch (self, "_CACHE", 6, 0)) && *svp) {
	csv->cache = (byte *)SvPV (*svp, len);

	csv->quote_char			= csv->cache[CACHE_ID_quote_char	];
	csv->escape_char		= csv->cache[CACHE_ID_escape_char	];
	csv->sep_char			= csv->cache[CACHE_ID_sep_char		];
	csv->binary			= csv->cache[CACHE_ID_binary		];

	csv->keep_meta_info		= csv->cache[CACHE_ID_keep_meta_info	];
	csv->alwasy_quote		= csv->cache[CACHE_ID_alwasy_quote	];

#if ALLOW_ALLOW
	csv->allow_loose_quotes		= csv->cache[CACHE_ID_allow_loose_quotes];
	csv->allow_loose_escapes	= csv->cache[CACHE_ID_allow_loose_escapes];
	csv->allow_whitespace		= csv->cache[CACHE_ID_allow_whitespace	];
	csv->allow_double_quoted	= csv->cache[CACHE_ID_allow_double_quoted];
	csv->verbatim			= csv->cache[CACHE_ID_verbatim		];
#endif
	csv->eol_is_cr			= csv->cache[CACHE_ID_eol_is_cr		];
	csv->eol_len			= csv->cache[CACHE_ID_eol_len		];
	if (csv->eol_len < 8)
	    csv->eol = (char *)&csv->cache[CACHE_ID_eol];
	else {
	    /* Was too long to cache. must re-fetch */
	    csv->eol = NULL;
	    csv->eol_is_cr = 0;
	    if ((svp = hv_fetch (self, "eol", 3, 0)) && *svp && SvOK (*svp)) {
		csv->eol = SvPV (*svp, len);
		csv->eol_len = len;
		csv->eol_is_cr = 0;
		}
	    }

	csv->types = NULL;
	if (csv->cache[CACHE_ID_has_types]) {
	    if ((svp = hv_fetch (self, "_types",   6, 0)) && *svp && SvOK (*svp)) {
		csv->types = SvPV (*svp, len);
		csv->types_len = len;
		}
	    }
	}
    else {
	csv->quote_char = '"';
	if ((svp = hv_fetch (self, "quote_char", 10, 0)) && *svp) {
	    if (SvOK (*svp)) {
		ptr = SvPV (*svp, len);
		csv->quote_char = len ? *ptr : (char)0;
		}
	    else
		csv->quote_char = (char)0;
	    }

	csv->escape_char = '"';
	if ((svp = hv_fetch (self, "escape_char", 11, 0)) && *svp) {
	    if (SvOK (*svp)) {
		ptr = SvPV (*svp, len);
		csv->escape_char = len ? *ptr : (char)0;
		}
	    else
		csv->escape_char = (char)0;
	    }
	csv->sep_char = ',';
	if ((svp = hv_fetch (self, "sep_char", 8, 0)) && *svp && SvOK (*svp)) {
	    ptr = SvPV (*svp, len);
	    if (len)
		csv->sep_char = *ptr;
	    }

	csv->eol = NULL;
	csv->eol_is_cr = 0;
	if ((svp = hv_fetch (self, "eol",      3, 0)) && *svp && SvOK (*svp)) {
	    csv->eol = SvPV (*svp, len);
	    csv->eol_len = len;
	    if (len == 1 && *csv->eol == CH_CR)
		csv->eol_is_cr = 1;
	    }

	csv->types = NULL;
	if ((svp = hv_fetch (self, "_types",   6, 0)) && *svp && SvOK (*svp)) {
	    csv->types = SvPV (*svp, len);
	    csv->types_len = len;
	    }

	csv->binary			= bool_opt ("binary");
	csv->keep_meta_info		= bool_opt ("keep_meta_info");
	csv->alwasy_quote		= bool_opt ("always_quote");
#if ALLOW_ALLOW
	csv->allow_loose_quotes		= bool_opt ("allow_loose_quotes");
	csv->allow_loose_escapes	= bool_opt ("allow_loose_escapes");
	csv->allow_whitespace		= bool_opt ("allow_whitespace");
	csv->allow_double_quoted	= bool_opt ("allow_double_quoted");
	csv->verbatim			= bool_opt ("verbatim");
#endif

	if ((csv->cache = (byte *)malloc (32))) {
	    csv->cache[CACHE_ID_quote_char]		= csv->quote_char;
	    csv->cache[CACHE_ID_escape_char]		= csv->escape_char;
	    csv->cache[CACHE_ID_sep_char]		= csv->sep_char;
	    csv->cache[CACHE_ID_binary]			= csv->binary;

	    csv->cache[CACHE_ID_keep_meta_info]		= csv->keep_meta_info;
	    csv->cache[CACHE_ID_alwasy_quote]		= csv->alwasy_quote;

#if ALLOW_ALLOW
	    csv->cache[CACHE_ID_allow_loose_quotes]	= csv->allow_loose_quotes;
	    csv->cache[CACHE_ID_allow_loose_escapes]	= csv->allow_loose_escapes;
	    csv->cache[CACHE_ID_allow_whitespace]	= csv->allow_whitespace;
	    csv->cache[CACHE_ID_allow_double_quoted]	= csv->allow_double_quoted;
	    csv->cache[CACHE_ID_verbatim]		= csv->verbatim;
#endif
	    csv->cache[CACHE_ID_eol_is_cr]		= csv->eol_is_cr;
	    csv->cache[CACHE_ID_eol_len]		= csv->eol_len;
	    if (csv->eol_len > 0 && csv->eol_len < 8 && csv->eol)
		strcpy ((char *)&csv->cache[CACHE_ID_eol], csv->eol);
	    csv->cache[CACHE_ID_has_types]		= csv->types ? 1 : 0;

	    if ((csv->tmp = newSVpv ((char *)csv->cache, 32)))
		hv_store (self, "_CACHE", 6, csv->tmp, 0);
	    }
	}


    csv->used = 0;
    } /* SetupCsv */

static int Print (csv_t *csv, SV *dst)
{
    int		result;

    if (csv->useIO) {
	SV *tmp = newSVpv (csv->buffer, csv->used);
	dSP;
	PUSHMARK (sp);
	EXTEND (sp, 2);
	PUSHs ((dst));
	PUSHs (tmp);
	PUTBACK;
	result = perl_call_method ("print", G_SCALAR);
	SPAGAIN;
	if (result)
	    result = POPi;
	PUTBACK;
	SvREFCNT_dec (tmp);
	}
    else {
	sv_catpvn (SvRV (dst), csv->buffer, csv->used);
	result = TRUE;
	}
    csv->used = 0;
    return result;
    } /* Print */

#define CSV_PUT(csv,dst,c)  {				\
    if ((csv)->used == sizeof ((csv)->buffer) - 1)	\
        Print ((csv), (dst));				\
    (csv)->buffer[(csv)->used++] = (c);			\
    }

/* Should be extended for EBCDIC ? */
#define is_csv_binary(ch) ((ch < CH_SPACE || ch >= CH_DEL) && ch != CH_TAB)

static int Combine (csv_t *csv, SV *dst, AV *fields)
{
    int		i;

    if (csv->sep_char == csv->quote_char || csv->sep_char == csv->escape_char) {
	SetDiag (csv, 1001);
	return FALSE;
	}

    for (i = 0; i <= av_len (fields); i++) {
	SV    **svp;

	if (i > 0)
	    CSV_PUT (csv, dst, csv->sep_char);
	if ((svp = av_fetch (fields, i, 0)) && *svp && SvOK (*svp)) {
	    STRLEN	 len;
	    char	*ptr = SvPV (*svp, len);
	    int		 quoteMe = csv->alwasy_quote;

	    /* Do we need quoting? We do quote, if the user requested
	     * (alwasy_quote), if binary or blank characters are found
	     * and if the string contains quote or escape characters.
	     */
	    if (!quoteMe &&
	       ( quoteMe = (!SvIOK (*svp) && !SvNOK (*svp) && csv->quote_char))) {
		char	*ptr2;
		STRLEN	 l;

		for (ptr2 = ptr, l = len; l; ++ptr2, --l) {
		    byte	c = *ptr2;

		    if (c <= 0x20 || (c >= 0x7f && c <= 0xa0)  ||
		       (csv->quote_char  && c == csv->quote_char) ||
		       (csv->sep_char    && c == csv->sep_char)   ||
		       (csv->escape_char && c == csv->escape_char)) {
			/* Binary character */
			break;
			}
		    }
		quoteMe = (l > 0);
		}
	    if (quoteMe)
		CSV_PUT (csv, dst, csv->quote_char);
	    while (len-- > 0) {
		char	c = *ptr++;
		int	e = 0;

		if (!csv->binary && is_csv_binary (c)) {
		    SvREFCNT_inc (*svp);
		    unless (hv_store (csv->self, "_ERROR_INPUT", 12, *svp, 0))
			SvREFCNT_dec (*svp);
		    SetDiag (csv, 2110);
		    return FALSE;
		    }
		if (csv->quote_char  && c == csv->quote_char)
		    e = 1;
		else
		if (csv->escape_char && c == csv->escape_char)
		    e = 1;
		else
		if (c == (char)0) {
		    e = 1;
		    c = '0';
		    }
		if (e && csv->escape_char)
		    CSV_PUT (csv, dst, csv->escape_char);
		CSV_PUT (csv, dst, c);
		}
	    if (quoteMe)
		CSV_PUT (csv, dst, csv->quote_char);
	    }
	}
    if (csv->eol_len) {
	STRLEN	len = csv->eol_len;
	char   *ptr = csv->eol;

	while (len--)
	    CSV_PUT (csv, dst, *ptr++);
	}
    if (csv->used)
	Print (csv, dst);
    return TRUE;
    } /* Combine */

#if MAINT_DEBUG
static char str_parsed[40];
#endif
static void ParseError (csv_t *csv, int xse)
{
    if (csv->tmp) {
	if (hv_store (csv->self, "_ERROR_INPUT", 12, csv->tmp, 0))
	    SvREFCNT_inc (csv->tmp);
	}
    SetDiag (csv, xse);
    } /* ParseError */

static int CsvGet (csv_t *csv, SV *src)
{
    unless (csv->useIO)
	return EOF;

    {   int	result;

	dSP;
	PUSHMARK (sp);
	EXTEND (sp, 1);
	PUSHs (src);
	PUTBACK;
	result = perl_call_method ("getline", G_SCALAR);
	SPAGAIN;
	csv->tmp = result ? POPs : NULL;
	PUTBACK;
	}
    if (csv->tmp && SvOK (csv->tmp)) {
	csv->bptr = SvPV (csv->tmp, csv->size);
	csv->used = 0;
#if ALLOW_ALLOW
	if (csv->verbatim && csv->eol_len && csv->size >= csv->eol_len) {
	    int i, match = 1;
	    for (i = 1; i <= (int)csv->eol_len; i++) {
		unless (csv->bptr[csv->size - i] == csv->eol[csv->eol_len - i]) {
		    match = 0;
		    break;
		    }
		}
	    if (match) {
		csv->size -= csv->eol_len;
		csv->bptr[csv->size] = (char)0;
		SvCUR_set (csv->tmp, csv->size);
		}
	    }
#endif
	if (csv->size) 
	    return ((byte)csv->bptr[csv->used++]);
	}
    csv->useIO |= useIO_EOF;
    return EOF;
    } /* CsvGet */

#define ERROR_INSIDE_QUOTES(diag_code) {	\
    SvREFCNT_dec (insideQuotes);		\
    ParseError (csv, diag_code);		\
    return FALSE;				\
    }
#define ERROR_INSIDE_FIELD(diag_code) {		\
    SvREFCNT_dec (insideField);			\
    ParseError (csv, diag_code);		\
    return FALSE;				\
    }

#define CSV_PUT_SV(sv,c) {			\
    len = SvCUR ((sv));				\
    SvGROW ((sv), len + 2);			\
    *SvEND ((sv)) = c;				\
    SvCUR_set ((sv), len + 1);			\
    }

#define CSV_GET					\
    ((c_ungetc != EOF)				\
	? c_ungetc				\
	: ((csv->used < csv->size)		\
	    ? ((byte)csv->bptr[(csv)->used++])	\
	    : CsvGet (csv, src)))

#if ALLOW_ALLOW
#define AV_PUSH(sv) {				\
    *SvEND (sv) = (char)0;			\
    if (csv->allow_whitespace)			\
	strip_trail_whitespace (sv);		\
    av_push (fields, sv);			\
    if (csv->keep_meta_info) {			\
	av_push (fflags, newSViv (f));		\
	f = 0;					\
	}					\
    }
#else
#define AV_PUSH(sv) {				\
    *SvEND (sv) = (char)0;			\
    av_push (fields, sv);			\
    if (csv->keep_meta_info) {			\
	av_push (fflags, newSViv (f));		\
	f = 0;					\
	}					\
    }
#endif

static void strip_trail_whitespace (SV *sv)
{
    STRLEN len;
    char   *s = SvPV (sv, len);
    unless (s && len) return;
    while (s[len - 1] == CH_SPACE || s[len - 1] == CH_TAB) {
	s[--len] = (char)0;
	}
    SvCUR_set (sv, len);
    } /* strip_trail_whitespace */

static int Parse (csv_t *csv, SV *src, AV *fields, AV *fflags)
{
    int		 c, f = 0;
    int		 c_ungetc		= EOF;
    int		 waitingForField	= 1;
    SV		*insideQuotes		= NULL;
    SV		*insideField		= NULL;
    STRLEN	 len;
    int		 seenSomething		= FALSE;
#if MAINT_DEBUG
    int		 spl			= -1;
    memset (str_parsed, 0, 40);
#endif

    if (csv->sep_char == csv->quote_char || csv->sep_char == csv->escape_char) {
	SetDiag (csv, 1001);
	return FALSE;
	}

    while ((c = CSV_GET) != EOF) {
	seenSomething = TRUE;
#if MAINT_DEBUG
	if (++spl < 39) str_parsed[spl] = c;
#endif
restart:
	if (c == csv->sep_char) {
#if MAINT_DEBUG > 1
	    fprintf (stderr, "# %d/%d/%d pos %d = SEP '%c'\n",
		waitingForField ? 1 : 0, insideQuotes ? 1 : 0,
		insideField     ? 1 : 0, spl, c);
#endif
	    if (waitingForField) {
		av_push (fields, newSVpv ("", 0));
#if ALLOW_ALLOW
		if (csv->keep_meta_info)
		    av_push (fflags, newSViv (f));
#endif
		}
	    else
	    if (insideQuotes)
		CSV_PUT_SV (insideQuotes, c)
	    else {
		AV_PUSH (insideField);
		insideField = NULL;
		waitingForField = 1;
		}
	    } /* SEP char */
	else
	if (c == CH_NL) {
#if MAINT_DEBUG > 1
	    fprintf (stderr, "# %d/%d/%d pos %d = NL\n",
		waitingForField ? 1 : 0, insideQuotes ? 1 : 0,
		insideField     ? 1 : 0, spl);
#endif
	    if (waitingForField) {
		av_push (fields, newSVpv ("", 0));
#if ALLOW_ALLOW
		if (csv->keep_meta_info)
		    av_push (fflags, newSViv (f));
#endif
		return TRUE;
		}

	    if (insideQuotes) {
		f |= CSV_FLAGS_BIN;
		unless (csv->binary)
		    ERROR_INSIDE_QUOTES (2021);

		CSV_PUT_SV (insideQuotes, c);
		}
#if ALLOW_ALLOW
	    else
	    if (csv->verbatim) {
		f |= CSV_FLAGS_BIN;
		unless (csv->binary)
		    ERROR_INSIDE_FIELD (2030);

		CSV_PUT_SV (insideField, c);
		}
#endif
	    else {
		AV_PUSH (insideField);
		return TRUE;
		}
	    } /* CH_NL */
	else
	if (c == CH_CR
#if ALLOW_ALLOW
	    && !(csv->verbatim)
#endif
	    ) {
#if MAINT_DEBUG > 1
	    fprintf (stderr, "# %d/%d/%d pos %d = CR\n",
		waitingForField ? 1 : 0, insideQuotes ? 1 : 0,
		insideField     ? 1 : 0, spl);
#endif
	    if (waitingForField) {
		int	c2;

		if (csv->eol_is_cr) {
		    c = CH_NL;
		    goto restart;
		    }

		c2 = CSV_GET;

		if (c2 == EOF) {
		    insideField = newSVpv ("", 0);
		    waitingForField = 0;
		    c = EOF;
		    goto restart;
		    }

		if (c2 == CH_NL) {
		    c = CH_NL;
		    goto restart;
		    }

		ERROR_INSIDE_FIELD (2031);
		}

	    if (insideQuotes) {
		f |= CSV_FLAGS_BIN;
		unless (csv->binary)
		    ERROR_INSIDE_QUOTES (2022);

		CSV_PUT_SV (insideQuotes, c);
		}
	    else {
		int	c2;

		if (csv->eol_is_cr) {
		    AV_PUSH (insideField);
		    return TRUE;
		    }

		c2 = CSV_GET;

		if (c2 == CH_NL) {
		    AV_PUSH (insideField);
		    return TRUE;
		    }

		ERROR_INSIDE_FIELD (2032);
		}
	    } /* CH_CR */
	else
	if (c == csv->quote_char) {
#if MAINT_DEBUG > 1
	    fprintf (stderr, "# %d/%d/%d pos %d = QUO '%c'\n",
		waitingForField ? 1 : 0, insideQuotes ? 1 : 0,
		insideField     ? 1 : 0, spl, c);
#endif
	    if (waitingForField) {
		insideQuotes = newSVpv ("", 0);
		f |= CSV_FLAGS_QUO;
		waitingForField = 0;
		}
	    else
	    if (insideQuotes) {
		int	c2;

		if (!csv->escape_char || c != csv->escape_char) {
		    /* Field is terminated */
		    AV_PUSH (insideQuotes);
		    insideQuotes = NULL;
		    waitingForField = 1;
		    c2 = CSV_GET;

#if ALLOW_ALLOW
		    if (csv->allow_whitespace) {
			while (c2 == CH_SPACE || c2 == CH_TAB) {
			    c2 = CSV_GET;
			    }
			}
#endif

		    if (c2 == csv->sep_char)
			continue;

		    if (c2 == EOF)
			return TRUE;

		    if (c2 == CH_CR) {
			int	c3;

			if (csv->eol_is_cr)
			    return TRUE;

			c3 = CSV_GET;
			if (c3 == CH_NL)
			    return TRUE;

			ParseError (csv, 2010);
			return FALSE;
			}

		    if (c2 == CH_NL)
			return TRUE;

		    ParseError (csv, 2011);
		    return FALSE;
		    }

		c2 = CSV_GET;

#if ALLOW_ALLOW
		if (csv->allow_whitespace) {
		    while (c2 == CH_SPACE || c2 == CH_TAB) {
			c2 = CSV_GET;
			}
		    }
#endif

		if (c2 == EOF) {
		    AV_PUSH (insideQuotes);
		    return TRUE;
		    }

		if (c2 == csv->sep_char) {
		    AV_PUSH (insideQuotes);
		    insideQuotes = NULL;
		    waitingForField = 1;
		    }
		else
		if (c2 == '0')
		    CSV_PUT_SV (insideQuotes, 0)
		else
		if (c2 == csv->quote_char  ||  c2 == csv->sep_char)
		    CSV_PUT_SV (insideQuotes, c2)
		else
		if (c2 == CH_NL) {
		    AV_PUSH (insideQuotes);
		    return TRUE;
		    }

		else {
		    if (c2 == CH_CR) {
			int	c3;

			if (csv->eol_is_cr) {
			    AV_PUSH (insideQuotes);
			    return TRUE;
			    }

			c3 = CSV_GET;

			if (c3 == CH_NL) {
			    AV_PUSH (insideQuotes);
			    return TRUE;
			    }
			}
#if ALLOW_ALLOW
		    if (csv->allow_whitespace) {
			while (c2 == CH_SPACE || c2 == CH_TAB) {
			    c2 = CSV_GET;
			    }
			if (c2 == csv->sep_char || c2 == EOF) {
			    c = c2;
			    goto restart;
			    }
			}
#endif
		    ERROR_INSIDE_QUOTES (2023);
		    }
		}
	    else
	    /* ! wiatingForField, !InsideQuotes */
	    if (csv->quote_char && csv->quote_char != csv->escape_char) {
		if (is_csv_binary (c)) {
		    f |= CSV_FLAGS_BIN;
		    unless (csv->binary)
			ERROR_INSIDE_FIELD (2033);
		    }

		CSV_PUT_SV (insideField, c);
		}
	    else
#if ALLOW_ALLOW
	    if (csv->allow_loose_quotes) { /* 1,foo "boo" d'uh,1 */
		f |= CSV_FLAGS_EIF;
		CSV_PUT_SV (insideField, c);
		}
	    else
#endif
		ERROR_INSIDE_FIELD (2034);
	    } /* QUO char */
	else
	if (csv->escape_char && c == csv->escape_char) {
#if MAINT_DEBUG > 1
	    fprintf (stderr, "# %d/%d/%d pos %d = ESC '%c'\n",
		waitingForField ? 1 : 0, insideQuotes ? 1 : 0,
		insideField     ? 1 : 0, spl, c);
#endif
	    /*  This means quote_char != escape_char  */
	    if (waitingForField) {
		insideField = newSVpv ("", 0);
		waitingForField = 0;
		}
	    else
	    if (insideQuotes) {
		int	c2 = CSV_GET;

		if (c2 == EOF)
		    ERROR_INSIDE_QUOTES (2024);

		if (c2 == '0')
		    CSV_PUT_SV (insideQuotes, 0)
		else
		if ( c2 == csv->quote_char  || c2 == csv->sep_char ||
		     c2 == csv->escape_char
#if ALLOW_ALLOW
		     || csv->allow_loose_escapes
#endif
		     )
		    CSV_PUT_SV (insideQuotes, c2)
		else
		    ERROR_INSIDE_QUOTES (2025);
		}
	    else
	    if (insideField) {
		int	c2 = CSV_GET;

		if (c2 == EOF)
		    ERROR_INSIDE_FIELD (2035);

		CSV_PUT_SV (insideField, c2);
		}
	    else
		ERROR_INSIDE_FIELD (2036); /* I think there's no way to get here */
	    } /* ESC char */
	else {
#if MAINT_DEBUG > 1
	    fprintf (stderr, "# %d/%d/%d pos %d = === '%c' '%c'\n",
		waitingForField ? 1 : 0, insideQuotes ? 1 : 0,
		insideField     ? 1 : 0, spl, c, c_ungetc);
#endif
	    if (waitingForField) {
#if ALLOW_ALLOW
		if (csv->allow_whitespace && (c == CH_SPACE || c == CH_TAB)) {
		    do {
			c = CSV_GET;
			} while (c == CH_SPACE || c == CH_TAB);
		    goto restart;
		    }
#endif

		insideField = newSVpv ("", 0);
		waitingForField = 0;
		goto restart;
		}

	    if (insideQuotes) {
		if (is_csv_binary (c)) {
		    f |= CSV_FLAGS_BIN;
		    unless (csv->binary)
			ERROR_INSIDE_QUOTES (2026);
		    }

		CSV_PUT_SV (insideQuotes, c);
		}
	    else {
		if (is_csv_binary (c)) {
		    f |= CSV_FLAGS_BIN;
		    unless (csv->binary)
			ERROR_INSIDE_FIELD (2037);
		    }

		CSV_PUT_SV (insideField, c);
		}
	    }

	/* continue */
#if ALLOW_ALLOW
	if (csv->useIO && csv->verbatim && csv->used == csv->size)
	    break;
#endif
	}

    if (waitingForField) {
	if (seenSomething) {
	    av_push (fields, newSVpv ("", 0));
#if ALLOW_ALLOW
	    if (csv->keep_meta_info)
		av_push (fflags, newSViv (f));
#endif
	    }
	else {
	    if (csv->useIO) {
		SetDiag (csv, 2012);
		return FALSE;
		}
	    }
	}
    else
    if (insideQuotes) {
	ERROR_INSIDE_QUOTES (2027);
	}
    else
    if (insideField)
	AV_PUSH (insideField);
    return TRUE;
    } /* Parse */

static int xsParse (HV *hv, AV *av, AV *avf, SV *src, bool useIO)
{
    csv_t	csv;
    int		result;

    SetupCsv (&csv, hv);
    if ((csv.useIO = useIO)) {
	csv.tmp  = NULL;
	csv.size = 0;
	}
    else {
	csv.tmp  = src;
	csv.bptr = SvPV (src, csv.size);
	}
    hv_delete (hv, "_ERROR_INPUT", 12, G_DISCARD);
    result = Parse (&csv, src, av, avf);
#ifdef ALLOW_ALLOW
    if (csv.useIO & useIO_EOF)
	hv_store (hv, "_EOF", 4, &PL_sv_yes, 0);
    else
	hv_store (hv, "_EOF", 4, &PL_sv_no,  0);
#endif
    if (result && csv.types) {
	I32	i;
	STRLEN	len = av_len (av);
	SV    **svp;

	for (i = 0; i <= (I32)len && i <= (I32)csv.types_len; i++) {
	    if ((svp = av_fetch (av, i, 0)) && *svp && SvOK (*svp)) {
		switch (csv.types[i]) {
		    case CSV_XS_TYPE_IV:
			sv_setiv (*svp, SvIV (*svp));
			break;

		    case CSV_XS_TYPE_NV:
			sv_setnv (*svp, SvNV (*svp));
			break;

		    default:
			break;
		    }
		}
	    }
	}
    return result;
    } /* xsParse */

static int xsCombine (HV *hv, AV *av, SV *io, bool useIO)
{
    csv_t	csv;

    SetupCsv (&csv, hv);
    csv.useIO = useIO;
    return Combine (&csv, io, av);
    } /* xsCombine */

#define _is_arrayref(f) \
    ( f && SvOK (f) && SvROK (f) && SvTYPE (SvRV (f)) == SVt_PVAV )

MODULE = Text::CSV_XS		PACKAGE = Text::CSV_XS

PROTOTYPES: DISABLE

SV*
Combine (self, dst, fields, useIO)
    SV		*self
    SV		*dst
    SV		*fields
    bool	 useIO

  PPCODE:
    HV	*hv;
    AV	*av;

    CSV_XS_SELF;
    av = (AV*)SvRV (fields);
    ST (0) = xsCombine (hv, av, dst, useIO) ? &PL_sv_yes : &PL_sv_undef;
    XSRETURN (1);
    /* XS Combine */

SV*
Parse (self, src, fields, fflags)
    SV		*self
    SV		*src
    SV		*fields
    SV		*fflags

  PPCODE:
    HV	*hv;
    AV	*av;
    AV	*avf;

    CSV_XS_SELF;
    av  = (AV*)SvRV (fields);
#if ALLOW_ALLOW
    avf = (AV*)SvRV (fflags);
#endif

    ST (0) = xsParse (hv, av, avf, src, 0) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN (1);
    /* XS Parse */

void
print (self, io, fields)
    SV		*self
    SV		*io
    SV		*fields

  PPCODE:
    HV	 *hv;
    AV	 *av;

    CSV_XS_SELF;
    unless (_is_arrayref (fields))
      croak ("Expected fields to be an array ref");

    av = (AV*)SvRV (fields);

    ST (0) = xsCombine (hv, av, io, 1) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN (1);
    /* XS print */

void
getline (self, io)
    SV		*self
    SV		*io

  PPCODE:
    HV	*hv;
    AV	*av;
    AV	*avf;

    CSV_XS_SELF;
    av  = newAV ();
    avf = newAV ();
    ST (0) = xsParse (hv, av, avf, io, 1)
	?  sv_2mortal (newRV_noinc ((SV *)av))
	: &PL_sv_undef;
    XSRETURN (1);
    /* XS getline */
