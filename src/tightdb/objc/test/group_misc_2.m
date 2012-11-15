//
//  group_misc_2.m
//  TightDB
//
// Demo code for short tutorial using Objective-C interface
//

#import <SenTestingKit/SenTestingKit.h>

#import <tightdb/objc/tightdb.h>
#import <tightdb/objc/group.h>

TIGHTDB_TABLE_DEF_4(MyTable,
                    String, Name,
                    Int,    Age,
                    Bool,   Hired,
                    Int,    Spare)

TIGHTDB_TABLE_DEF_2(MyTable2,
                    Bool,   Hired,
                    Int,    Age)

TIGHTDB_TABLE_IMPL_4(MyTable,
                     String, Name,
                     Int,    Age,
                     Bool,   Hired,
                     Int,    Spare)

TIGHTDB_TABLE_IMPL_2(MyTable2,
                     Bool,   Hired,
                     Int,    Age)

TIGHTDB_TABLE_2(QueryTable,
                Int,    First,
                String, Second)

@interface MACTestGroupMisc2 : SenTestCase
@end
@implementation MACTestGroupMisc2

- (void)testGroup_Misc2
{
    Group *group = [Group group];
    // Create new table in group
    MyTable *table = [group getTable:@"employees" withClass:[MyTable class]];
    NSLog(@"Table: %@", table);
    // Add some rows
    [table addName:@"John" Age:20 Hired:YES Spare:0];
    [table addName:@"Mary" Age:21 Hired:NO Spare:0];
    [table addName:@"Lars" Age:21 Hired:YES Spare:0];
    [table addName:@"Phil" Age:43 Hired:NO Spare:0];
    [table addName:@"Anni" Age:54 Hired:YES Spare:0];

    NSLog(@"MyTable Size: %lu", [table count]);

    //------------------------------------------------------

    size_t row;
    row = [table.Name find:@"Philip"];    // row = (size_t)-1
    NSLog(@"Philip: %zu", row);
    STAssertEquals(row, (size_t)-1,@"Philip should not be there");
    row = [table.Name find:@"Mary"];
    NSLog(@"Mary: %zu", row);
    STAssertEquals(row, (size_t)1,@"Mary should have been there");

    TableView *view = [table.Age findAll:21];
    size_t cnt = [view count];            // cnt = 2
    STAssertEquals(cnt, (size_t)2,@"Should be two rows in view");

    //------------------------------------------------------

    MyTable2 *table2 = [[MyTable2 alloc] init];

    // Add some rows
    [table2 addHired:YES Age:20];
    [table2 addHired:NO Age:21];
    [table2 addHired:YES Age:22];
    [table2 addHired:NO Age:43];
    [table2 addHired:YES Age:54];

    // Create query (current employees between 20 and 30 years old)
    MyTable2_Query *q = [[[table2 getQuery].Hired equal:YES].Age between:20 to:30];

    // Get number of matching entries
    NSLog(@"Query count: %zu", [q count]);
    STAssertEquals([q count], (size_t)2,@"Expected 2 rows in query");

     // Get the average age - currently only a low-level interface!
    double avg = [q.Age avg];
    NSLog(@"Average: %f", avg);
    STAssertEquals(avg, 21.0,@"Expected 20.5 average");

    // Execute the query and return a table (view)
    TableView *res = [q findAll];
    for (size_t i = 0; i < [res count]; i++) {
        // cursor missing. Only low-level interface!
        NSLog(@"%zu: is %lld years old",i , [res get:1 ndx:i]);
    }

    //------------------------------------------------------

    // Write to disk
    [group write:@"employees.tightdb"];

    // Load a group from disk (and print contents)
    Group *fromDisk = [Group groupWithFilename:@"employees.tightdb"];
    MyTable *diskTable = [fromDisk getTable:@"employees" withClass:[MyTable class]];

    [diskTable addName:@"Anni" Age:54 Hired:YES Spare:0];
//    [diskTable insertAtIndex:2 Name:@"Thomas" Age:41 Hired:NO Spare:1];
    NSLog(@"Disktable size: %zu", [diskTable count]);
    for (size_t i = 0; i < [diskTable count]; i++) {
        MyTable_Cursor *cursor = [diskTable objectAtIndex:i];
        NSLog(@"%zu: %@", i, [cursor Name]);
        NSLog(@"%zu: %@", i, cursor.Name);
        NSLog(@"%zu: %@", i, [diskTable getString:0 ndx:i]);
    }

    // Write same group to memory buffer
    size_t len;
    const char* const buffer = [group writeToMem:&len];

    // Load a group from memory (and print contents)
    Group *fromMem = [Group groupWithBuffer:buffer len:len];
    MyTable *memTable = [fromMem getTable:@"employees" withClass:[MyTable class]];
    for (size_t i = 0; i < [memTable count]; i++) {
        // ??? cursor
        NSLog(@"%zu: %@", i, memTable.Name);
    }
}


- (void)testQuery
{
    Group *group = [Group group];
    QueryTable *table = [group getTable:@"Query table" withClass:[QueryTable class]];

    // Add some rows
    [table addFirst:2 Second:@"a"];
    [table addFirst:4 Second:@"a"];
    [table addFirst:5 Second:@"b"];
    [table addFirst:8 Second:@"The quick brown fox"];

    {
        QueryTable_Query *q = [[table getQuery].First between:3 to:7]; // Between
        STAssertEquals((size_t)2,   [q count], @"count != 2");
//        STAssertEquals(9,   [q.First sum]); // Sum
        STAssertEquals(4.5, [q.First avg], @"Avg!=4.5"); // Average
//        STAssertEquals(4,   [q.First min]); // Minimum
//        STAssertEquals(5,   [q.First max]); // Maximum
    }
    {
        QueryTable_Query *q = [[table getQuery].Second contains:@"quick" caseSensitive:NO]; // String contains
        STAssertEquals((size_t)1, [q count], @"count != 1");
    }
    {
        QueryTable_Query *q = [[table getQuery].Second beginsWith:@"The" caseSensitive:NO]; // String prefix
        STAssertEquals((size_t)1, [q count], @"count != 1");
    }
    {
        QueryTable_Query *q = [[table getQuery].Second endsWith:@"The" caseSensitive:NO]; // String suffix
        STAssertEquals((size_t)0, [q count], @"count != 1");
    }
    {
        QueryTable_Query *q = [[[table getQuery].Second notEqual:@"a" caseSensitive:NO].Second notEqual:@"b" caseSensitive:NO]; // And
        STAssertEquals((size_t)1, [q count], @"count != 1");
    }
    {
        QueryTable_Query *q = [[[[table getQuery].Second notEqual:@"a" caseSensitive:NO] or].Second notEqual:@"b" caseSensitive:NO]; // Or
        STAssertEquals((size_t)4, [q count], @"count != 1");
    }
    {
        QueryTable_Query *q = [[[[[[[table getQuery].Second equal:@"a" caseSensitive:NO] group].First less:3] or].First greater:5] endgroup]; // Parentheses
        STAssertEquals((size_t)1, [q count], @"count != 1");
    }
    {
        QueryTable_Query *q = [[[[[table getQuery].Second equal:@"a" caseSensitive:NO].First less:3] or].First greater:5]; // No parenthesis
        STAssertEquals((size_t)2, [q count], @"count != 2");
        TableView *tv = [q findAll];
        STAssertEquals((size_t)2, [tv count], @"count != 2");
        STAssertEquals((int64_t)8, [tv get:0 ndx:1], @"First != 8");
    }
}

/*
 * Tables can contain other tables, however this is not yet supported
 * by the high level API. The following illustrates how to do it
 * through the low level API.
 */
- (void)testSubtables
{
    Group *group = [Group group];
    OCTopLevelTable *table = [group getTable:@"table" withClass:[OCTopLevelTable class]];

    // Specify the table schema
    {
        OCSpec *s = [table getSpec];
        [s addColumn:COLUMN_TYPE_INT name:@"int"];
        {
            OCSpec *sub = [s addColumnTable:@"tab"];
            [sub addColumn:COLUMN_TYPE_INT name:@"int"];
        }
        [s addColumn:COLUMN_TYPE_MIXED name:@"mix"];
        [table updateFromSpec];
    }

    int COL_TABLE_INT = 0;
    int COL_TABLE_TAB = 1;
    int COL_TABLE_MIX = 2;
    int COL_SUBTABLE_INT = 0;

    // Add a row to the top level table
    [table addRow];
    [table set:COL_TABLE_INT ndx:0 value:700];

    // Add two rows to the subtable
    Table *subtable = [table getTable:COL_TABLE_TAB ndx:0];
    [subtable addRow];
    [subtable set:COL_SUBTABLE_INT ndx:0 value:800];
    [subtable addRow];
    [subtable set:COL_SUBTABLE_INT ndx:1 value:801];

    // Make the mixed values column contain another subtable
    [table setMixed:COL_TABLE_MIX ndx:0 value: [OCMixed mixedWithTable]];

/* Fails!!!
    // Specify its schema
    OCTopLevelTable *subtable2 = [table getTopLevelTable:COL_TABLE_MIX ndx:0];
    {
        OCSpec *s = [subtable2 getSpec];
        [s addColumn:COLUMN_TYPE_INT name:@"int"];
        [subtable2 updateFromSpec:[s getRef]];
    }
    // Add a row to it
    [subtable2 addRow];
    [subtable2 set:COL_SUBTABLE_INT ndx:0 value:900];
*/
}

@end