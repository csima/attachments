package main

import (
	"github.com/aws/aws-sdk-go/aws"
	b64 "encoding/base64"
	//"github.com/aws/aws-sdk-go/aws/awserr"
	//"github.com/aws/aws-sdk-go/aws/awsutil"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/aws/session"
   	"gopkg.in/redis.v3"
	"strings"
	"fmt"
	"bytes"
	"os"
	"bufio"
	"log"
	"reflect"
	"time"
)

func setupAmazon() *s3.S3 {
	// the file location and load default profile
	creds := credentials.NewEnvCredentials()
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