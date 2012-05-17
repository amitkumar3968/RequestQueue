//
//  RootViewController.m
//  ImageLoader
//
//  Created by Nick Lockwood on 18/01/2012.
//  Copyright Charcoal Design 2012
//

#import "RootViewController.h"
#import "RequestQueue.h"


@interface RootViewController ()

@property (nonatomic, retain) NSMutableArray *urlStrings;
@property (nonatomic, retain) NSMutableDictionary *images;
@property (nonatomic, retain) NSMutableDictionary *progressStatuses;

@end


@implementation RootViewController

@synthesize loadUnloadButton;
@synthesize urlStrings;
@synthesize images;
@synthesize progressStatuses;

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.loadUnloadButton = [[[UIBarButtonItem alloc] initWithTitle:@"Load"
															  style:UIBarButtonItemStylePlain
															 target:self
															 action:@selector(loadUnloadImages)] autorelease];
	
	self.navigationItem.rightBarButtonItem = loadUnloadButton;
	self.navigationItem.title = @"Images";
}

- (void)refreshView
{	
	//refresh table
	[self.tableView reloadData];
	
	//update button state
	if ([[RequestQueue mainQueue] requestCount])
	{
		//loading
		loadUnloadButton.enabled = NO;
		loadUnloadButton.title = @"Wait";
	}
	else if ([urlStrings count])
	{
		//finished
		loadUnloadButton.enabled = YES;
		loadUnloadButton.title = @"Clear";
	}
	else
	{
		//idle
		loadUnloadButton.enabled = YES;
		loadUnloadButton.title = @"Load";
	}
}

- (void)loadUnloadImages
{	
	//select action
	if ([urlStrings count])
	{
		//clear images
		self.urlStrings = nil;
		self.images = nil;
		self.progressStatuses = nil;
		
		//refresh view
		[self refreshView];
	}
	else
	{
		//reset data source
		NSString *path = [[NSBundle mainBundle] pathForResource:@"Images" ofType:@"plist"];
		self.urlStrings = [NSMutableArray arrayWithContentsOfFile:path];
		self.images = [NSMutableDictionary dictionary];
		self.progressStatuses = [NSMutableDictionary dictionary];
		[self refreshView];
		
		//load images
		for (NSString *urlString in urlStrings)
		{
			//create operation
			NSURL *URL = [NSURL URLWithString:urlString];
			NSURLCacheStoragePolicy policy = NSURLCacheStorageNotAllowed;
			NSURLRequest *request = [NSURLRequest requestWithURL:URL cachePolicy:policy timeoutInterval:15.0];
			RQOperation *operation = [RQOperation operationWithRequest:request];

			//completion handler
			operation.completionHandler = ^(NSURLResponse *response, NSData *data, NSError *error) {
				
				if (!error)
				{
					//image downloaded
					UIImage *image = [UIImage imageWithData:data];
                    if (image)
                    {
                        [images setObject:image forKey:urlString];
                    }
                    else
                    {
                        //image error
                        NSInteger index = [urlStrings indexOfObject:urlString];
                        [urlStrings replaceObjectAtIndex:index withObject:@"Image was missing or corrupt"];
                    }
				}
				else
				{
					//loading error
					NSInteger index = [urlStrings indexOfObject:urlString];
					[urlStrings replaceObjectAtIndex:index withObject:[error localizedDescription]];
				}
				
				//refresh view
				[self refreshView];
			};
			
			//progress handler
			operation.downloadProgressHandler = ^(float progress, NSInteger bytesTransferred, NSInteger totalBytes) {
				
				//update progress
				[progressStatuses setObject:[NSNumber numberWithFloat:progress] forKey:urlString];
				
				//refresh view
				[self refreshView];
			};
			
			//add operation to queue
			[[RequestQueue mainQueue] addOperation:operation];
		}

	}
}

#pragma mark Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	
    return [urlStrings count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		
		UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
		progressView.frame = CGRectMake(80.0f, 16.0f, 220.0f, progressView.frame.size.height);
		progressView.tag = 99;
		[cell addSubview:progressView];
	}
    
	NSString *urlString = [urlStrings objectAtIndex:indexPath.row];
	cell.imageView.image = [images objectForKey:urlString];
	UIProgressView *progressView = (UIProgressView *)[cell viewWithTag:99];
	progressView.progress = [[progressStatuses objectForKey:urlString] floatValue];
	
    return cell;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
	//create view controller
	UIViewController *viewController = [[UIViewController alloc] init];

	//set view
	NSString *urlString = [urlStrings objectAtIndex:indexPath.row];
	UIImage *image = [images objectForKey:urlString];
	UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
	viewController.view = imageView;
	[imageView release];
	
	//pass the selected object to the new view controller.
	[self.navigationController pushViewController:viewController animated:YES];
	[viewController release];
}

#pragma mark Memory management

- (void)viewDidUnload
{	
	self.loadUnloadButton = nil;
	[super viewDidUnload];
}

- (void)dealloc
{	
	[loadUnloadButton release];
	[urlStrings release];
	[images release];
    [super dealloc];
}


@end

