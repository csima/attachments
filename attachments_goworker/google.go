package main

import (
	b64 "encoding/base64"
    "github.com/davecgh/go-spew/spew"
    "golang.org/x/oauth2"
	"google.golang.org/api/gmail/v1"
	"strings"
	"log"
	"os"
)

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
			os.Exit(1)
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
			body: msg.Raw,
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
