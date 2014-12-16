//
//  SharesTableViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 15.09.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "SharesTableViewController.h"
#import "DataModel.h"
#import "MBProgressHUD.h"

@interface SharesTableViewController ()

@property (weak, nonatomic) id<SharesTableViewControllerDelegate> sharesDelegate;
@property (strong, nonatomic) NSMutableArray* nodes;

@end

@implementation SharesTableViewController

- (id)initWithDelegate:(id<SharesTableViewControllerDelegate>)delegate
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
		self.sharesDelegate = delegate;
		_nodes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = @"Select shares";
    self.clearsSelectionOnViewWillAppear = NO;
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
	if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
		self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];
		self.navigationItem.rightBarButtonItem.tintColor = [UIColor whiteColor];
	}
	
	[MBProgressHUD showHUDAddedTo:self.tableView animated:YES];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
		NSArray* hosts = [DataModel auth].allKeys;
		for (NSString* host in hosts) {
			id result = [[DataModel sharedInstance].provider fetchAtPath:[NSString stringWithFormat:@"smb://%@", host]];
			if ([result isKindOfClass:[NSError class]]) {
				NSLog(@"ERROR: %@", result);
			} else {
				if ([result isKindOfClass:[NSArray class]]) {
					for (KxSMBItem* item in result) {
						[_nodes addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:item, @"item", [_sharesDelegate hasNodeWithPath:item.path], @"checked", nil]];
					}
				} else if ([result isKindOfClass:[KxSMBItem class]]) {
					KxSMBItem* item = (KxSMBItem*)result;
					[_nodes addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:item, @"item", [_sharesDelegate hasNodeWithPath:item.path], @"checked", nil]];
				}
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.tableView animated:YES];
			[self.tableView reloadData];
		});
	});
}

- (void)cancel
{
	[self dismissViewControllerAnimated:YES completion:^(){}];
}

- (void)done
{
	[_sharesDelegate didSelectShares:_nodes];
	[self dismissViewControllerAnimated:YES completion:^(){}];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _nodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
	NSDictionary* row = [_nodes objectAtIndex:indexPath.row];
	KxSMBItem* item = [row objectForKey:@"item"];
	cell.textLabel.text = [[item.path lastPathComponent] stringByDeletingPathExtension];
	if ([[row objectForKey:@"checked"] boolValue]) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSMutableDictionary* item = [_nodes objectAtIndex:indexPath.row];
	BOOL checked = [[item objectForKey:@"checked"] boolValue];
	[item setObject:[NSNumber numberWithBool:!checked] forKey:@"checked"];
	[tableView reloadData];
}

@end
