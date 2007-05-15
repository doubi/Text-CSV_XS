/*  Copyright (c) 2007-2007 H.Merijn Brand.  All rights reserved.
 *  Copyright (c) 1998-2001 Jochen Wiedmann. All rights reserved.
 *  This program is free software; you can redistribute it and/or
 *  modify it under the same terms as Perl itself.
 */

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include "ppport.h"

#define CSV_XS_TYPE_PV 0
#define CSV_XS_TYPE_IV 1
#define CSV_XS_TYPE_NV 2

#define CSV_FLAGS_QUO	0x0001
#define CSV_FLAGS_BIN	0x0002

#define unless(expr)	if (!(expr))

#define CSV_XS_SELF					\
    if (!self || !SvOK (self) || !SvROK (self) ||	\
	 SvTYPE (SvRV (self)) != SVt_PVHV)		\
        croak ("self is not a hash ref");		\
    hv = (HV*)SvRV (self)

#define	byte	unsigned char
typedef struct {
    HV*		 self;
    byte	 quote_char;
    byte	 escape_char;
    byte	 sep_char;
    int		 binary;
    int		 flags;
    int		 alwaysQuote;
    char	 buffer[1024];
    STRLEN	 used;
    STRLEN	 size;
    char	*bptr;
    int		 useIO;
    SV		*tmp;
    char	*types;
    STRLEN	 types_len;
    } csv_t;

#define bool_opt(o) \
    ((svp = hv_fetch (self, o, strlen (o), 0)) && *svp ? SvTRUE (*svp) : 0)

static void SetupCsv (csv_t *csv, HV *self)
{
    SV	       **svp;
    STRLEN	 len;
    char	*ptr;

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
    csv->types = NULL;
    if ((svp = hv_fetch (self, "_types",   6, 0)) && *svp && SvOK (*svp)) {
	STRLEN len;
	csv->types = SvPV (*svp, len);
	csv->types_len = len;
	}

    csv->binary		= bool_opt ("binary");
    csv->flags		= bool_opt ("keep_meta_info");
    csv->alwaysQuote	= bool_opt ("always_quote");

    csv->self = self;
    csv->used = 0;
    } /* SetupCsv */

static int Print (csv_t *csv, SV *dst)
{
    int		result;

    if (csv->useIO) {
	SV* tmp = newSVpv (csv->buffer, csv->used);
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

static int Combine (csv_t *csv, SV *dst, AV *fields, SV *eol)
{
    int		i;

    if (csv->sep_char == csv->quote_char || csv->sep_char == csv->escape_char)
	return FALSE;

    for (i = 0; i <= av_len (fields); i++) {
	SV    **svp;

	if (i > 0)
	    CSV_PUT (csv, dst, csv->sep_char);
	if ((svp = av_fetch (fields, i, 0)) && *svp && SvOK (*svp)) {
	    STRLEN	 len;
	    char	*ptr = SvPV (*svp, len);
	    int		 quoteMe = csv->alwaysQuote;

	    /* Do we need quoting? We do quote, if the user requested
	     * (alwaysQuote), if binary or blank characters are found
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

		if (!csv->binary &&
		   (c != '\t' && (c < '\040' || c > '\176'))) {
		    SvREFCNT_inc (*svp);
		    unless (hv_store (csv->self, "_ERROR_INPUT", 12, *svp, 0))
			SvREFCNT_dec (*svp);
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
    if (eol && SvOK (eol)) {
	STRLEN	len;
	char   *ptr = SvPV (eol, len);

	while (len--)
	    CSV_PUT (csv, dst, *ptr++);
	}
    if (csv->used)
	Print (csv, dst);
    return TRUE;
    } /* Combine */

static void ParseError (csv_t *csv)
{
    if (csv->tmp) {
	if (hv_store (csv->self, "_ERROR_INPUT", 12, csv->tmp, 0))
	    SvREFCNT_inc (csv->tmp);
	}
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
	if (csv->size)
	    return ((byte)csv->bptr[csv->used++]);
	}
    return EOF;
    } /* CsvGet */

#define ERROR_INSIDE_QUOTES {			\
    SvREFCNT_dec (insideQuotes);		\
    ParseError (csv);				\
    return FALSE;				\
    }
#define ERROR_INSIDE_FIELD {			\
    SvREFCNT_dec (insideField);			\
    ParseError (csv);				\
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

#define AV_PUSH(sv) {				\
    *SvEND (sv) = (char)0;			\
    av_push (fields, sv);			\
    if (csv->flags) {				\
	av_push (fflags, newSViv (f));		\
	f = 0;					\
	}					\
    }

static int Parse (csv_t *csv, SV *src, AV *fields, AV *fflags)
{
    int		 c, f = 0;
    int		 c_ungetc		= EOF;
    int		 waitingForField	= 1;
    SV		*insideQuotes		= NULL;
    SV		*insideField		= NULL;
    STRLEN	 len;
    int		 seenSomething		= FALSE;

    if (csv->sep_char == csv->quote_char || csv->sep_char == csv->escape_char)
	return FALSE;

    while ((c = CSV_GET) != EOF) {
	seenSomething = TRUE;
restart:
	if (c == csv->sep_char) {
	    if (waitingForField) {
		av_push (fields, newSVpv ("", 0));
		if (csv->flags)
		    av_push (fflags, newSViv (f));
		}
	    else
	    if (insideQuotes) 
		CSV_PUT_SV (insideQuotes, c)
	    else {
		AV_PUSH (insideField);
		insideField = NULL;
		waitingForField = 1;
		}
	    }
	else
	if (c == '\012') {
	    if (waitingForField) {
		av_push (fields, newSVpv ("", 0));
		if (csv->flags)
		    av_push (fflags, newSViv (f));
		return TRUE;
		}

	    if (insideQuotes) {
		f |= CSV_FLAGS_BIN;
		unless (csv->binary)
		    ERROR_INSIDE_QUOTES;

		CSV_PUT_SV (insideQuotes, c);
		}
	    else {
		AV_PUSH (insideField);
		return TRUE;
		}
	    }
	else
	if (c == '\015') {
	    if (waitingForField) {
		int	c2 = CSV_GET;

		if (c2 == EOF) {
		    insideField = newSVpv ("", 0);
		    waitingForField = 0;
		    goto restart;
		    }

		if (c2 == '\012') {
		    c = '\012';
		    goto restart;
		    }

		c_ungetc = c2;
		insideField = newSVpv ("", 0);
		waitingForField = 0;
		goto restart;
		}

	    if (insideQuotes) {
		f |= CSV_FLAGS_BIN;
		unless (csv->binary)
		    ERROR_INSIDE_QUOTES;

		CSV_PUT_SV (insideQuotes, c);
		}
	    else {
		int	c2 = CSV_GET;

		if (c2 == '\012') {
		    AV_PUSH (insideField);
		    return TRUE;
		    }

		ERROR_INSIDE_FIELD;
		}
	    }
	else
	if (c == csv->quote_char) {
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
		    if (c2 == csv->sep_char)
			continue;

		    if (c2 == EOF)
			return TRUE;

		    if (c2 == '\015') {
			int	c3 = CSV_GET;

			if (c3 == '\012')
			    return TRUE;

			ParseError (csv);
			return FALSE;
			}

		    if (c2 == '\012')
			return TRUE;

		    ParseError (csv);
		    return FALSE;
		    }

		c2 = CSV_GET;
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
		if (c2 == '\012') {
		    AV_PUSH (insideQuotes);
		    return TRUE;
		    }

		else {
		    if (c2 == '\015') {
			int	c3 = CSV_GET;

			if (c3 == '\012') {
			    AV_PUSH (insideQuotes);
			    return TRUE;
			    }
			}
		    ERROR_INSIDE_QUOTES;
		    }
		}
	    else
	    if (csv->quote_char && csv->quote_char != csv->escape_char) {
		if (c != '\011' && (c < '\040' || c > '\176')) {
		    f |= CSV_FLAGS_BIN;
		    if (!csv->binary)
			ERROR_INSIDE_FIELD;
		    }

		CSV_PUT_SV (insideField, c);
		}
	    else
		ERROR_INSIDE_FIELD;
	    }
	else
	if (csv->escape_char && c == csv->escape_char) {
	    /*  This means quote_char != escape_char  */
	    if (waitingForField) {
		insideField = newSVpv ("", 0);
		waitingForField = 0;
		}
	    else
	    if (insideQuotes) {
		int	c2 = CSV_GET;

		if (c2 == EOF)
		    ERROR_INSIDE_QUOTES;

		if (c2 == '0')
		    CSV_PUT_SV (insideQuotes, 0)
		else
		if (c2 == csv->quote_char || c2 == csv->sep_char ||
		    c2 == csv->escape_char) {
		    /* c2 == csv->escape_char added 28-06-1999,
		     * Pavel Kotala <pkotala@logis.cz>
		     */
		    CSV_PUT_SV (insideQuotes, c2);
		    }
		else
		    ERROR_INSIDE_QUOTES;
		}
	    else
	    if (insideField) {
		int	c2 = CSV_GET;

		if (c2 == EOF)
		    ERROR_INSIDE_FIELD;

		CSV_PUT_SV (insideField, c2);
		}
	    else
		ERROR_INSIDE_FIELD;
	    }
	else {
	    if (waitingForField) {
		insideField = newSVpv ("", 0);
		waitingForField = 0;
		goto restart;
		}

	    if (insideQuotes) {
		if (c != '\011' && (c < '\040' || c > '\176')) {
		    f |= CSV_FLAGS_BIN;
		    if (!csv->binary)
			ERROR_INSIDE_QUOTES;
		    }

		CSV_PUT_SV (insideQuotes, c);
		}
	    else {
		if (c != '\011' && (c < '\040' || c > '\176')) {
		    f |= CSV_FLAGS_BIN;
		    if (!csv->binary)
			ERROR_INSIDE_QUOTES;
		    }

		CSV_PUT_SV (insideField, c);
		}
	    }
	}

    if (waitingForField) {
	if (seenSomething) {
	    av_push (fields, newSVpv ("", 0));
	    if (csv->flags)
		av_push (fflags, newSViv (f));
	    }
	else {
	    if (csv->useIO)
		return FALSE;
	    }
	}
    else
    if (insideQuotes)
	ERROR_INSIDE_QUOTES
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
	STRLEN	size;
	csv.tmp  = src;
	csv.bptr = SvPV (src, size);
	csv.size = size;
	}
    result = Parse (&csv, src, av, avf);
    if (result && csv.types) {
	I32	i, len = av_len (av);
	SV    **svp;

	for (i = 0; i <= len && i <= csv.types_len; i++) {
	    if ((svp = av_fetch (av, i, 0)) && *svp && SvOK (*svp)) {
		switch (csv.types[i]) {
		    case CSV_XS_TYPE_IV:
			sv_setiv (*svp, SvIV (*svp));
			break;

		    case CSV_XS_TYPE_NV:
			sv_setnv (*svp, SvIV (*svp));
			break;
		    }
		}
	    }
	}
    return result;
    } /* xsParse */

static int xsCombine (HV *hv, AV *av, SV *io, bool useIO, SV *eol)
{
    csv_t	csv;

    SetupCsv (&csv, hv);
    csv.useIO = useIO;
    return Combine (&csv, io, av, eol);
    } /* xsCombine */

#define _is_arrayref(f) \
    ( f && SvOK (f) && SvROK (f) && SvTYPE (SvRV (f)) == SVt_PVAV )

MODULE = Text::CSV_XS		PACKAGE = Text::CSV_XS

PROTOTYPES: ENABLE

SV*
Combine (self, dst, fields, useIO, eol)
    SV		*self
    SV		*dst
    SV		*fields
    bool	 useIO
    SV		 *eol

  PROTOTYPE:	$$$$
  PPCODE:
    HV	*hv;
    AV	*av;

    CSV_XS_SELF;
    if (_is_arrayref (fields))
	av = (AV*)SvRV (fields);
    else
	croak ("fields is not an array ref");

    ST (0) = xsCombine (hv, av, dst, useIO, eol) ? &PL_sv_yes : &PL_sv_undef;
    XSRETURN (1);
    /* XS Combine */

SV*
Parse (self, src, fields, fflags, useIO)
    SV		*self
    SV		*src
    SV		*fields
    SV		*fflags
    bool	 useIO

  PROTOTYPE:	$$$$
  PPCODE:
    HV	*hv;
    AV	*av;
    AV	*avf;

    CSV_XS_SELF;
    if (_is_arrayref (fields))
	av  = (AV*)SvRV (fields);
    else
	croak ("fields is not an array ref");
    if (_is_arrayref (fflags))
	avf = (AV*)SvRV (fflags);
    else
	croak ("fflags is not an array ref");

    ST (0) = xsParse (hv, av, avf, src, useIO) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN (1);
    /* XS Parse */

void
print (self, io, fields)
    SV		*self
    SV		*io
    SV		*fields

  PROTOTYPE:	$$$
  PPCODE:
    HV	 *hv;
    AV	 *av;
    SV	 *eol;
    SV	**svp;

    CSV_XS_SELF;
    unless (_is_arrayref (fields))
      croak ("Expected fields to be an array ref");

    av = (AV*)SvRV (fields);
    if ((svp = hv_fetch (hv, "eol", 3, FALSE)))
	eol = *svp;
    else
	eol = &PL_sv_undef;

    ST (0) = xsCombine (hv, av, io, 1, eol) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN (1);
    /* XS print */

void
getline (self, io)
    SV		*self
    SV		*io

  PROTOTYPE:	$;$
  PPCODE:
    HV	*hv;
    AV	*av;
    AV	*avf;

    CSV_XS_SELF;
    hv_delete (hv, "_ERROR_INPUT", 12, G_DISCARD);
    av  = newAV ();
    avf = newAV ();
    ST (0) = xsParse (hv, av, avf, io, 1)
	?  sv_2mortal (newRV_noinc ((SV*)av))
	: &PL_sv_undef;
    XSRETURN (1);
    /* XS getline */
