package main

import (
	"context"
	"flag"
	"fmt"
	"io"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/smithy-go/middleware"
	smithyhttp "github.com/aws/smithy-go/transport/http"
)

type S3GetObjectAPI interface {
	GetObject(ctx context.Context, params *s3.GetObjectInput, optFns ...func(*s3.Options)) (*s3.GetObjectOutput, error)
}

func addHeaderMiddleware(headerName, headerValue string) func(*middleware.Stack) error {
	return func(stack *middleware.Stack) error {
		return stack.Build.Add(
			middleware.BuildMiddlewareFunc("AddCustomHeader", func(
				ctx context.Context,
				in middleware.BuildInput,
				next middleware.BuildHandler,
			) (
				middleware.BuildOutput,
				middleware.Metadata,
				error,
			) {
				if req, ok := in.Request.(*smithyhttp.Request); ok {
					req.Header.Set(headerName, headerValue)
				}
				return next.HandleBuild(ctx, in)
			}), middleware.Before)
	}
}

func GetObjectViaAccessPoint(ctx context.Context, client S3GetObjectAPI, accessPointArn, objectKey, headerName, headerValue string) ([]byte, error) {
	result, err := client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(accessPointArn),
		Key:    aws.String(objectKey),
	}, s3.WithAPIOptions(
		addHeaderMiddleware(headerName, headerValue),
	))

	if err != nil {
		return nil, fmt.Errorf("failed to get object: %w", err)
	}
	defer result.Body.Close()

	body, err := io.ReadAll(result.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read object: %w", err)
	}

	return body, nil
}

func main() {
	accessPointArn := flag.String("access-point-arn", "", "Your access point")
	objectKey := flag.String("db-path", "", "Path to database object")
	customHeaderValue := flag.String("query", "", "SQL query")
	flag.Parse()

	const customHeaderName = "x-amz-meta-request-sql"

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		fmt.Printf("failed to load config %v", err)
		return
	}

	s3Client := s3.NewFromConfig(cfg)
	fmt.Println("calling object")

	objectData, err := GetObjectViaAccessPoint(context.TODO(), s3Client, *accessPointArn, *objectKey, customHeaderName, *customHeaderValue)
	if err != nil {
		fmt.Printf("get object error: %v", err)
		return
	}

	fmt.Printf("object size: %d bytes\n", len(objectData))
}
