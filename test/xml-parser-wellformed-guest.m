#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void check(BOOL condition, const char *name)
{
    if (!condition) {
        fprintf(stderr, "FAIL XML well-formedness: %s\n", name);
        failures++;
    }
}

static BOOL parser_accepts(NSString *xml, BOOL *reportsError)
{
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    BOOL accepted = [parser parse];
    if (reportsError)
        *reportsError = [parser parserError] != nil;
    [parser release];
    return accepted;
}

static NSXMLDocument *document_for(NSString *xml, NSError **outError)
{
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:data
                                                           options:0
                                                             error:&error];
    // The error out-parameter is only meaningful when no document was built;
    // callers assert rejection, not incidental wording or error codes.
    if (outError)
        *outError = error;
    return document;
}

static void accepts_valid(NSString *xml, const char *name)
{
    check(parser_accepts(xml, NULL), name);
    NSXMLDocument *document = document_for(xml, NULL);
    check([[[document rootElement] name] isEqualToString:@"root"], name);
    [document release];
}

static void rejects_invalid(NSString *xml, const char *name)
{
    BOOL reportsError = NO;
    check(!parser_accepts(xml, &reportsError), name);
    check(reportsError, name);

    NSError *error = nil;
    NSXMLDocument *document = document_for(xml, &error);
    check(document == nil, name);
    check(error != nil, name);
    [document release];
}

int main(void)
{
    @autoreleasepool {
        accepts_valid(@"<root/>", "self-closed root");
        accepts_valid(@"<root><child/></root>", "nested self-closed child");
        accepts_valid(@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                      @"<root attr=\"value\">text<child>nested</child></root>\n",
                      "declaration, attributes, nested elements and trailing space");
        accepts_valid(@"<root>a &amp; b</root>", "character reference");
        accepts_valid(@"<root><![CDATA[a < b]]></root>", "CDATA section");

        // The exact PackageKit fixture that previously produced a document
        // with only a start tag: the root element is never closed.
        rejects_invalid(@"<pkg-info identifier=\"bad\">",
                        "unclosed root element with attributes");
        rejects_invalid(@"<root><child>", "unclosed nested elements");
        rejects_invalid(@"<root><child></root>", "mismatched closing tag");
        rejects_invalid(@"<root attr=\"unfinished",
                        "unfinished attribute literal");
        rejects_invalid(@"<root", "unfinished start tag");
        rejects_invalid(@"&amp", "unfinished entity reference");
        rejects_invalid(@"<root><![CDATA[x", "unfinished CDATA section");
        rejects_invalid(@"</root>", "closing tag without an open element");

        // Valid nested shape remains inspectable through the document API.
        NSXMLDocument *document = document_for(
            @"<root><child attr=\"v\">text</child></root>", NULL);
        check([[[document rootElement] name] isEqualToString:@"root"],
              "root element name");
        check([[[document rootElement] children] count] == 1,
              "root element child count");
        [document release];
    }

    printf("XML-PARSER-WELLFORMED failures=%d\n", failures);
    if (failures == 0)
        printf("XML_PARSER_WELLFORMED_OK\n");
    return failures != 0;
}
