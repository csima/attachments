package main // import "github.com/badkode/attachments_go"

import (
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/s3"
    "github.com/jrallison/go-workers"
	"gopkg.in/redis.v3"
    //"github.com/davecgh/go-spew/spew"
	"strings"
	"fmt"
	"os"
    "io"
	"bufio"
	"log"
	"reflect"
	"time"
    "strconv"
)

type message struct {
	size    int64
	gmailID string
	date    string // retrieved from message header
	snippet string
	body string
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
    Addr:     REDIS,
    Password: "", // no password set
    DB:       0,  // use default DB
})
 
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
    defer resp.Body.Close()
    
	fileTimestamp := *resp.Metadata["Date"]
    reader := bufio.NewReader(resp.Body)
    io.Copy(file, reader)
   
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
        
        // Add +1 to ziplist for compress phase
        total, err := redisClient.Get(accountId + ":" + identityId + ":zip:list_total").Result()
        if err != nil {
            log.Printf("Redis GET failed %v", err)
        }
        totalint, err := strconv.Atoi(total)
        if err != nil {
            log.Printf("Failed to convert '%s' to int", total)
        }
        totalint = totalint + 1
        redisClient.Set(accountId + ":" + identityId + ":zip:list_total", totalint,0)
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
		
	params["client_id"] = GOOGLE_CLIENT_ID
	params["client_secret"] = GOOGLE_CLIENT_SECRET
	
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
var AWS_REGION = os.Getenv("AWS_REGION")
var REDIS=os.Getenv("REDIS")
var GOOGLE_CLIENT_ID=os.Getenv("GOOGLE_CLIENT_ID")
var GOOGLE_CLIENT_SECRET=os.Getenv("GOOGLE_CLIENT_SECRET")

func main() {
  log.Printf(S3_BUCKET)
  
  workers.Configure(map[string]string{
    // location of redis instance
    "server":  REDIS,
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
  workers.Process("default", MessageWorker, 30)
  workers.Process("high", MainWorker, 10)
  workers.Process("compress", CompressWorker, 10)
  
  // stats will be available at http://localhost:8080/stats
  //go workers.StatsServer(8080)

  // Blocks until process is told to exit via unix signal
  workers.Run()
}
