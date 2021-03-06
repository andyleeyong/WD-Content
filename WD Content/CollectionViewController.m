//
//  ViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 29.11.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "CollectionViewController.h"
#import "Cell.h"
#import "InfoViewController.h"
#import "DataModel.h"
#import "SVProgressHUD.h"
#import "SearchInfoTableViewController.h"
#import "VideoViewController.h"
#import "UIViewController+UIViewControllerExtensions.h"

@interface CollectionViewController ()

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSArray* nodes;
@property (readwrite, nonatomic) enum ViewMode viewMode;

@end

@implementation CollectionViewController

- (void)awakeFromNib
{
	[super awakeFromNib];
	BOOL isTable = [[NSUserDefaults standardUserDefaults] boolForKey:@"TableMode"];
	if (isTable) {
		_viewMode = Table;
	} else {
		_viewMode = Collection;
	}
}

- (void)setupBackButton {
	UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"backButton"]
															 style:UIBarButtonItemStylePlain
															target:self action:@selector(goBack)];
	back.tintColor = [UIColor whiteColor];
	self.navigationItem.leftBarButtonItem = back;
}

- (void)goBack {
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleUpdateInfoNotification:) name:UpdateInfoNotification object:nil];

	_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];

	UIBarButtonItem* refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(addNodesForRoot)];
	refresh.tintColor = [UIColor whiteColor];
	
	UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
	if (_viewMode == Collection) {
		[btn setImage:[UIImage imageNamed:@"list.png"] forState:UIControlStateNormal];
		_tableView.alpha = 0;
	} else {
		[btn setImage:[UIImage imageNamed:@"collection.png"] forState:UIControlStateNormal];
		_collectionView.alpha = 0;
	}
	[btn addTarget:self action:@selector(switchMode:) forControlEvents:UIControlEventTouchDown];
	UIBarButtonItem* compose = [[UIBarButtonItem alloc] initWithCustomView:btn];
	
	NSArray* items = @[refresh, compose];
	
	[self.navigationItem setRightBarButtonItems:items];
	self.title = _rootNode.name;
	if (_rootNode.parent != NULL) {
		[self setupBackButton];
	}
}

- (void)switchMode:(UIButton*)sender
{
	[UIView animateWithDuration:.3f animations:^{
		if (_viewMode == Collection) {
			_viewMode = Table;
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TableMode"];
			[sender setImage:[UIImage imageNamed:@"collection.png"] forState:UIControlStateNormal];
			_collectionView.alpha = 0;
			_tableView.alpha = 1;
		} else {
			_viewMode = Collection;
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"TableMode"];
			[sender setImage:[UIImage imageNamed:@"list.png"] forState:UIControlStateNormal];
			_collectionView.alpha = 1;
			_tableView.alpha = 0;
		}
		[[NSUserDefaults standardUserDefaults] synchronize];
	}];
}

-(void)handleUpdateInfoNotification:(NSNotification*)notification
{
	Node* target = (Node*)notification.object;
	for (Node* node in _nodes) {
		if ([node.path isEqual:target.path]) {
			_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];
			[_collectionView reloadData];
			[_tableView reloadData];
			break;
		}
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (_nodes.count == 0) {
		[self addNodesForRoot];
	}
}

- (Node*)nodeWithPath:(NSString*)path
{
	for (Node* node in _nodes) {
		if ([node.path isEqual:path]) {
			return node;
		}
	}
	return nil;
}

- (NSNumber*)hasNodeWithPath:(NSString*)path
{
	if ([self nodeWithPath:path]) {
		return [NSNumber numberWithBool:YES];
	} else {
		return [NSNumber numberWithBool:NO];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex) {
		[self addNodesForRoot];
	}
}

- (void)addNodesForRoot
{
	[SVProgressHUD showWithStatus:@"Update..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
		NSMutableArray* newItems = [NSMutableArray new];
		id result = [[DataModel sharedInstance].provider fetchAtPath:_rootNode.path];
		if ([result isKindOfClass:[NSError class]]) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[SVProgressHUD dismiss];
				UIAlertView* alert = [[UIAlertView alloc] initWithTitle:_rootNode.path
																message:@"Error connect. Retry?"
															   delegate:self
													  cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
				[alert show];
			});
			return;
		} else {
			if ([result isKindOfClass:[NSArray class]]) {
				for (KxSMBItem* item in result) {
					[self addItem:item toList:newItems];
				}
			} else if ([result isKindOfClass:[KxSMBItem class]]) {
				[self addItem:result toList:newItems];
			}
		}
		// add new nodes
		for (KxSMBItem* item in newItems) {
			if (![self nodeWithPath:item.path]) {
				[[DataModel sharedInstance] newNodeForItem:item withParent:_rootNode];
			}
		}
		// remove deleted
		NSArray* paths = [newItems valueForKeyPath:@"path"];
		for (Node* node in _nodes) {
			if (![paths containsObject:node.path]) {
				[[DataModel sharedInstance] deleteNode:node];
			}
		}
		_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];
		dispatch_async(dispatch_get_main_queue(), ^{
			[SVProgressHUD dismiss];
			[_collectionView reloadData];
			[_tableView reloadData];
		});
	});
}

-(void)addItem:(KxSMBItem*)item toList:(NSMutableArray*)list
{
	if ([item isKindOfClass:[KxSMBItemFile class]]) {
		NSArray* movieExtensions = @[@"mkv", @"avi", @"iso", @"ts", @"mov", @"m4v", @"mpg", @"mpeg", @"wmv", @"mp4"];
		if ([movieExtensions containsObject:item.path.pathExtension]) {
			[list addObject:item];
		}
	} else {
		NSLog(@"%@", item.path.lastPathComponent);
		if ([item.path.lastPathComponent containsString:@"System Volume Information"] ||
			[item.path.lastPathComponent containsString:@"$RECYCLE"] ||
			[item.path.lastPathComponent containsString:@"HFS+ Private Data"]) {
			return;
		}
		NSRange r = [item.path.lastPathComponent rangeOfString:@"."];
		if (r.location == NSNotFound || r.location > 0) {
			[list addObject:item];
		}
	}
}

#pragma mark - Collection View Data Sources

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return _nodes.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    Cell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"my_cell" forIndexPath:indexPath];
	Node *node = [_nodes objectAtIndex:indexPath.row];
	[cell setInfo:node];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	Node* node = [_nodes objectAtIndex:indexPath.row];
	UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
	[self selectNode:node fromRect:cell.frame inView:collectionView];
}

- (void)selectNode:(Node*)node fromRect:(CGRect)rect inView:(UIView*)view
{
	if ([node.isFile boolValue] == NO) {
		UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
		CollectionViewController *next = [storyboard instantiateViewControllerWithIdentifier:@"CollectionViewController"];
		next.rootNode = node;
		next.viewMode = _viewMode;
		[self.navigationController pushViewController:next animated:YES];
	}
	else {
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
																				 message:nil
																		  preferredStyle:UIAlertControllerStyleActionSheet];

		UIAlertAction *action = nil;
		action = [UIAlertAction actionWithTitle:@"Show Info" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			if (node.info) {
				[self performSegueWithIdentifier:@"ShowInfo" sender:node];
			} else {
				[self performSegueWithIdentifier:@"CreateInfo" sender:node];
			}
		}];
		[alertController addAction:action];
		action = [UIAlertAction actionWithTitle:@"Preview movie" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[self performSegueWithIdentifier:@"ShowVideo" sender:node];
		}];
		[alertController addAction:action];
		action = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
		[alertController addAction:action];
		
		if(IS_PAD) {
			UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:alertController];
			[popover presentPopoverFromRect:rect inView:view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		} else {
			[self presentViewController:alertController animated:YES completion:nil];
		}
	}
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	UINavigationController *vc = [segue destinationViewController];
	if ([[segue identifier] isEqualToString:@"CreateInfo"]) {
		SearchInfoTableViewController *next = (SearchInfoTableViewController*)vc.topViewController;
		next.node = sender;
	} else if ([[segue identifier] isEqualToString:@"ShowInfo"]) {
		InfoViewController *next = (InfoViewController*)vc.topViewController;
		[next setInfoForNode:sender];
	} else if ([[segue identifier] isEqualToString:@"ShowVideo"]) {
		VideoViewController *next = (VideoViewController*)vc.topViewController;
		next.node = sender;
	}
}

#pragma mark - UITableView delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return _nodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
	Node *node = [_nodes objectAtIndex:indexPath.row];
	cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
	cell.imageView.image = [node.info thumbnail] ? [UIImage imageWithData:node.info.thumbnail] : [UIImage imageWithData:node.image];
	cell.textLabel.numberOfLines = 0;
	cell.textLabel.text = [node.info title] ? node.info.title : node.name;
	cell.textLabel.backgroundColor = [UIColor clearColor];
	if ([node.isFile boolValue] == NO) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:17];
	} else {
		cell.accessoryType = UITableViewCellAccessoryDetailButton;
		cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:14];
		if (node.info) {
			cell.detailTextLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
			cell.detailTextLabel.text = node.info.release_date;
			cell.detailTextLabel.backgroundColor = [UIColor clearColor];
		}
	}
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Node* node = [_nodes objectAtIndex:indexPath.row];
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
	[self selectNode:node fromRect:cell.frame inView:tableView];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	Node* node = [_nodes objectAtIndex:indexPath.row];
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
	[self selectNode:node fromRect:cell.frame inView:tableView];
}

@end
