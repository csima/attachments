package main

import (
	"github.com/aws/aws-sdk-go/aws"
	b64 "encoding/base64"
	//"github.com/aws/aws-sdk-go/aws/awserr"
	//"github.com/aws/aws-sdk-go/aws/awsutil"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/aws/session"
    "github.com/jrallison/go-workers"
    //"github.com/aws/aws-sdk-go/service/s3/s3manager"
    "github.com/davecgh/go-spew/spew"
    "golang.org/x/oauth2"
	"google.golang.org/api/gmail/v1"
	"gopkg.in/redis.v3"
	"strings"
	"fmt"
	"bytes"
	//"net/http"
	"os"
	"bufio"
	"log"
	"reflect"
	"time"
	//"fmt"
)

type message struct {
	size    int64
	gmailID string
	date    string // retrieved from message header
	snippet string
	attachments []attachment
	subject string
}

type attachment struct {
	id string
	filename string
	data []byte
	encoded_data string
}

var redisClient = redis.NewClient(&redis.Options{
    Addr:     "localhost:6379",
    Password: "", // no password set
    DB:       0,  // use default DB
})
    
func setupAmazon() *s3.S3 {
	// the file location and load default profile
	creds := credentials.NewSharedCredentials("credentials", "default")
	_, err := creds.Get()
	
	if err != nil {
	     fmt.Println(err)
	     os.Exit(1)
	}
	
	svc := s3.New(session.New(), &aws.Config{Region: aws.String("us-west-1"), Credentials:creds, LogLevel: aws.LogLevel(1)})
	return svc
}

func s3Upload(svc *s3.S3, bucket string, filename string, data []byte, date string) (*s3.PutObjectOutput, error) {
	params := &s3.PutObjectInput{
	            Bucket:         aws.String(bucket),
	            Key:            aws.String(filename),
	            Body:         bytes.NewReader(data),
	            Metadata: map[string]*string{
                         "Date": aws.String(date), //required
                },
	    }
	resp, err := svc.PutObject(params)
	if err != nil {
		log.Printf("Error uploading to s3: %v", err)
		log.Printf("bucket: %s filename: %s date: %s", bucket, filename, date)
	}
	
	return resp, err
}
 
func getService(clientId string, clientSecret string, refreshToken string) *gmail.Service {
	config := &oauth2.Config{ClientID: clientId, ClientSecret: clientSecret, Scopes: strings.Fields("https://www.googleapis.com/auth/gmail.readonly"), Endpoint: oauth2.Endpoint{AuthURL:"https://accounts.google.com/o/oauth2/auth", TokenURL:"https://accounts.google.com/o/oauth2/token"}}

	t := &oauth2.Token{RefreshToken: refreshToken}
	client := config.Client(oauth2.NoContext,t)	
	srv, err := gmail.New(client)
	if err != nil {
    	log.Fatalf("Unable to retrieve gmail Client %v", err)
  	}
  	return srv
}

func messagesList(svc *gmail.Service, query string, accountId string, identityId string) []string {
	pageToken := ""
	messageIds := []string{}
	count := 0

	for {
		req := svc.Users.Messages.List("me").Q(query)
		if pageToken != "" {
			req.PageToken(pageToken)
		}
		
		r, err := req.Do()
		if err != nil {
			log.Fatalf("Unable to retrieve messages: %v", err)
		}
		
		for _, m := range r.Messages {
			messageIds = append(messageIds, m.Id)
			redisClient.LPush(accountId + ":" + identityId + ":messageids_list", m.Id)
		}
		
		count++
		log.Printf("Page %d", count)
		log.Printf("Messages count: %d", len(r.Messages))
		log.Printf("NextPageToken:")
		spew.Dump(r.NextPageToken)
		
		if r.NextPageToken == "" {
			break
		}
				
		pageToken = r.NextPageToken
		//req.PageToken(pageToken)
	}	
	
	log.Printf("Total Message count: %d", len(messageIds))
	return messageIds
}

func messagesGet(svc *gmail.Service, messageIds []string, accountId string, identityId string) []message {
	msgs := []message{}

	for _, m := range messageIds {
		msg, err := svc.Users.Messages.Get("me", m).Do()
		if err != nil {
			log.Printf("Unable to retrieve message %v: %v", m, err)
			return nil
		}
				
		var subject string = ""
		var attachments []attachment 
		
		for _, h := range msg.Payload.Headers {
			if h.Name == "Subject" {
				subject = h.Value
			}
		}
		
		date := ""
		for _, h := range msg.Payload.Headers {
			if h.Name == "Date" {
				date = h.Value
				break
			}
		}

		for _, part := range msg.Payload.Parts {			
			attachmentId := part.Body.AttachmentId
			if attachmentId != "" && part.Filename != "" {
				attachments = append(attachments, attachment{id: part.Body.AttachmentId, filename: part.Filename})
			} else if attachmentId == "" && part.Filename != "" {
				// We have the contents here - populate attachment
				raw, _ := b64.URLEncoding.DecodeString(part.Body.Data)
				attachments = append(attachments, attachment{id: part.Body.AttachmentId, filename: part.Filename, data: raw})
				//log.Printf("FILENAME: %s", part.Filename)
			}
			//log.Printf("%s : %s", subject, part.Filename)
		}
		
		msgs = append(msgs, message{
			size:    msg.SizeEstimate,
			gmailID: msg.Id,
			date:	 date,
			snippet: msg.Snippet,
			subject: subject,
			attachments: attachments,
		})
		
		redisClient.HSet(accountId + ":" + identityId + ":messageids", msg.Id, "true")
	}
	
	return msgs
}

func attachmentsGet(svc *gmail.Service, messages *[]message) {
	for i, _ := range *messages {
		for i2, _ := range (*messages)[i].attachments {
			msg, err := svc.Users.Messages.Attachments.Get("me", (*messages)[i].gmailID, (*messages)[i].attachments[i2].id).Do()
			if err != nil {
				log.Printf("Unable to retrieve message %v", err)
				return
			}
			raw, _ := b64.URLEncoding.DecodeString(msg.Data)
			(*messages)[i].attachments[i2].data = raw
		}
	}	
}

func slicer(a interface{}, b int) [][]interface{} {
	val := reflect.ValueOf(a)

	origLen := val.Len()
	outerLen := origLen / b
	if origLen%b > 0 {
		outerLen++
	}

	// Make the output slices with all the correct lengths
	c := make([][]interface{}, outerLen)

	itemsLeft := origLen
	for i := range c {
		if itemsLeft < b {
			c[i] = make([]interface{}, itemsLeft)
		} else {
			c[i] = make([]interface{}, b)
		}
		itemsLeft -= b
	}

	// now populate our slices via reflection
	for i, s := range c {
		subSlice := val.Slice(i*b, i*b+len(s))
		for j := 0; j < len(s); j++ {
			c[i][j] = subSlice.Index(j).Interface()
		}
	}

	return c
}

func s3Delete(svc *s3.S3, bucket string, keys []*s3.ObjectIdentifier) *s3.DeleteObjectsOutput {
		params := &s3.DeleteObjectsInput{
	        Bucket: aws.String(bucket),
	        Delete: &s3.Delete{Objects: keys},
		}
		result , err := svc.DeleteObjects(params)
		if err != nil {
			log.Printf("Error deleting from s3: %v", err)
		}
		return result
}

func s3MassDelete(svc *s3.S3, bucket string, key string) {
	params := &s3.ListObjectsInput{
		Bucket:       aws.String(bucket), // Required
		Prefix:       aws.String(key),
	}
	resp, err := svc.ListObjects(params)
	
	if err != nil {
		fmt.Println(err.Error())
		return
	}
	
	s3keys := []*s3.ObjectIdentifier{}
	
	for _, m := range resp.Contents {
		//log.Printf("key: %s", *m.Key)
		s3keys = append(s3keys, &s3.ObjectIdentifier{Key: m.Key})
	}
	
	if len(s3keys) > 1000 {
		sliced := slicer(s3keys,5)
		
		for _, keys := range sliced {
			vals := []*s3.ObjectIdentifier{}
			for _, v := range keys {
				vals = append(vals, v.(*s3.ObjectIdentifier))
			}
			result := s3Delete(svc, bucket, vals)
				
			if result == nil {
				log.Printf("s3 result is null")
			}
		}
	} else {
		result := s3Delete(svc,bucket,s3keys)
			
		if result == nil {
			log.Printf("s3 result is null")
		}
	}

}


func SaveManagerWorker(message *workers.Msg) {
	args,_ := message.Get("args").Array()
	params := args[0].(map[string]interface{})
	accountId := getParam("account_id", params)
	identityId := getParam("identity_id", params)

	svc := setupAmazon()
	
	redisClient.Del(accountId + ":" + identityId + ":zip:list")
	redisClient.Del(accountId + ":" + identityId + ":zip:list_complete")
		
	s3params := &s3.ListObjectsInput{
		Bucket:       aws.String(S3_BUCKET), // Required
		Prefix:       aws.String(accountId + "/" + identityId + "/"),
	}
	resp, err := svc.ListObjects(s3params)
	if err != nil {
		log.Printf("s3 ListObjectsInput failed: %v", err)
	}
	s3keys := []string{}
	
	for _, m := range resp.Contents {
		//log.Printf("key: %s", *m.Key)
		s3keys = append(s3keys, *m.Key)
	}
	
	redisClient.Set(accountId + ":" + identityId + ":zip:list_total", len(s3keys),0)
	
	for _, key := range s3keys {
		params["key"] = key
		params["jobcount"] = len(s3keys)
		log.Printf("%s:%d",key,len(s3keys))
		workers.Enqueue("save", "Add", params)
	}
}

func SaveWorker(message *workers.Msg) {
	accountId,_ := message.Get("args").Get("account_id").String()
	identityId,_ := message.Get("args").Get("identity_id").String()
	key,_ := message.Get("args").Get("key").String()
	jobcount,_ := message.Get("args").Get("jobcount").Int64()
	svc := setupAmazon()
	
	directory := accountId + "/" + identityId + "/"
	filename := strings.Replace(key, directory, "", -1)
	
	os.MkdirAll(directory, 0777);

	file, err := os.Create(directory + filename)
	if err != nil {
	    log.Fatal("Failed to create file", err)
	}
	defer file.Close()
	
	params := &s3.GetObjectInput{
		Bucket: aws.String(S3_BUCKET),
		Key: aws.String(key),
	}
	resp, err := svc.GetObject(params)
	if err != nil {
		log.Printf("Error in GetObject %v", err)
	}

	fileTimestamp := *resp.Metadata["Date"]
	
	scanner := bufio.NewScanner(resp.Body)
    for scanner.Scan() {
	    _, err := file.Write(scanner.Bytes())
		if err != nil {
			log.Printf("error writing file %v", err)
		}
    }
    if err := scanner.Err(); err != nil {
        fmt.Fprintln(os.Stderr, "There was an error with the scanner in attached container", err)
    }
    
	fmt.Println("Downloaded file", file.Name())
	
	timeStamp, err := time.Parse("Mon, 2 Jan 2006 15:04:05 -0700", fileTimestamp)
	if err != nil {
		log.Printf("Error in parsing time: %v", err)
	} else {
		err = os.Chtimes(file.Name(), timeStamp, timeStamp)
		if err != nil {
			log.Printf("Error in changing file timestamp: %v", err)
		}
	}
	
	/*
	downloader := s3manager.NewDownloaderWithClient(svc)
	numBytes, err := downloader.Download(file,
	    &s3.GetObjectInput{
	        Bucket: aws.String(S3_BUCKET),
	        Key:    aws.String(key),
	    })
	if err != nil {
	    fmt.Println("Failed to download file", err)
	    return
	}*/
	
	
	redisClient.LPush(accountId + ":" + identityId + ":zip:list", key)
	if err != nil {
		log.Printf("Failed to write to redis %v", err)
	}
	jobsCompleted, err := redisClient.LLen(accountId + ":" + identityId + ":zip:list").Result()
	if err != nil {
		log.Printf("Redis LLEN failed - could not pull jobs completed: %v", err)
	}
	if jobsCompleted == jobcount {
		log.Printf("Download from s3 complete")
		redisClient.Set(accountId + ":" + identityId + ":zip:list_complete", true, 0)
		workers.Enqueue("compress", "Add", message.Get("args"))
	}	
}



func MessageWorker(message *workers.Msg) {
	//log.Printf("MessageWorker called")

	account_id,_ := message.Get("args").Get("account_id").String()
	identity_id,_ := message.Get("args").Get("identity_id").String()
	refresh_token,_ := message.Get("args").Get("token").String()
	message_id,_ := message.Get("args").Get("message_ids").String()
	client_id,_ := message.Get("args").Get("client_id").String()
	client_secret,_ := message.Get("args").Get("client_secret").String()
	
/*
    log.Printf("account_id: %s", account_id)
    log.Printf("identity_id: %s", identity_id)
    log.Printf("refresh_token: %s", refresh_token)
    log.Printf("message_ids: %s", message_id)
    log.Printf("client_id: %s", client_id)
    log.Printf("client_secret: %s", client_secret)
*/
    
    googleService := getService(client_id, client_secret, refresh_token)
    msgs := messagesGet(googleService, []string{message_id}, account_id, identity_id)
    
    attachmentsGet(googleService, &msgs)
    
    svc := setupAmazon()
    for _,message := range msgs {
	    for _,attachment := range message.attachments {
			resp, _ := s3Upload(svc, "attachments.storage", account_id + "/" + identity_id + "/" + attachment.filename, attachment.data, message.date) 
			if resp == nil { log.Printf("ugh")}
			//spew.Dump(resp)
		}
	}
}

func MainWorker(message *workers.Msg) {
	args,_ := message.Get("args").Array()
	params := args[0].(map[string]interface{})
	
	//workers.Enqueue("zip", "Add", message.Get("args"))
	
	params["client_id"] = "518366790721-81mdsr326q9uq0iq0agr9c69dgchergq.apps.googleusercontent.com"
	params["client_secret"] = "_XTdy-qfJXEasfe2zgqAVWlR"
	
	client_id := getParam("client_id", params)
	client_secret := getParam("client_secret", params)
	account_id := getParam("account_id", params)
	identity_id := getParam("identity_id", params)
	refresh_token := getParam("token", params)
	query := getParam("query", params)
	
	log.Printf("client_id: %s", client_id)
    log.Printf("client_secret: %s", client_secret)
    log.Printf("account_id: %s", account_id)
    log.Printf("identity_id: %s", identity_id)
    log.Printf("refresh_token: %s", refresh_token)
    log.Printf("query: %s", query)
    
	svc := setupAmazon()
	s3MassDelete(svc,"attachments.storage", account_id + "/" + identity_id + "/")
	
	googleService := getService(client_id, client_secret, refresh_token)
	messageIds := messagesList(googleService, query, account_id, identity_id)
	for _, id := range messageIds {
		//log.Printf(id)
		params["message_ids"] = id
		workers.Enqueue("default", "Add", params)
	}
}

func getParam(key string, params map[string]interface{}) string {
	value := params[key]
	if value != nil {
		return value.(string)
	} else {
		return ""
	}
}

var S3_BUCKET = os.Getenv("S3_BUCKET")

func main() {
  log.Printf(S3_BUCKET)
  
  workers.Configure(map[string]string{
    // location of redis instance
    "server":  "localhost:6379",
    // instance of the database
    "database":  "0",
    // number of connections to keep open with redis
    "pool":    "30",
    // unique process id for this instance of workers (for proper recovery of inprogress jobs on crash)
    "process": "1",
  })

  // pull messages from "myqueue" with concurrency of 10
  workers.Process("save", SaveWorker, 20)
  workers.Process("zip", SaveManagerWorker, 10)
  workers.Process("default", MessageWorker, 20)
  workers.Process("high", MainWorker, 10)
  workers.Process("compress", CompressWorker, 10)
  
  // stats will be available at http://localhost:8080/stats
  //go workers.StatsServer(8080)

  // Blocks until process is told to exit via unix signal
  workers.Run()
}
