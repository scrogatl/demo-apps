package com.kafkaMSK;

import org.apache.kafka.clients.consumer.Consumer;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import com.newrelic.api.agent.NewRelic;
import com.newrelic.api.agent.Trace;
import java.util.Random;

import java.util.Collections;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;



public class KafkaMSK {

    private static final String DEMOGORGON_TOPIC = "demogorgon.ecommerce.cart";
    private static final String MSK_TOPIC = "MSKTopic";
    private static final String BOOTSTRAP_SERVERS = "";

    public static void main(String[] args) {
        ExecutorService executorService = Executors.newFixedThreadPool(3);

        executorService.submit(() -> produce());
        executorService.submit(() -> produce_demogorgon());
        executorService.submit(() -> consume());

        String result = KafkaMSK.executeWithTransaction("MyCustomTransaction", () -> {
            processData();
            return "Transaction Completed";
        });
        
        executorService.shutdown();
    }

    @Trace(dispatcher = true)
    public static void processData() {
        NewRelic.setTransactionName(null, "kafkaClient/processData");
        // Simulate some computation or business logic
        System.out.println("Processing data...");
    }

    @Trace(dispatcher = true)
    public static void produce() {
        NewRelic.setTransactionName(null, "kafkaClient/produce");
        System.out.println("produce() method invoked");
        Properties producerProps = new Properties();
        producerProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        producerProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        producerProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        Random random = new Random();

        Producer<String, String> producer = new KafkaProducer<>(producerProps);
        try {
            int i = 0;
            while(true) {
                String randTopic = new Random().nextBoolean() ? DEMOGORGON_TOPIC : MSK_TOPIC;
                producer.send(new ProducerRecord<>(randTopic, Integer.toString(i), "Sending a message! " + i));
                i++;
                int randomInt = random.nextInt(401)+100;
                // Sleep to simulate processing time (optional)
                try {
                    Thread.sleep(randomInt);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        } finally {
            producer.close();
        }
    }

    @Trace(dispatcher = true)
    public static void produce_demogorgon() {
        NewRelic.setTransactionName(null, "kafkaClient/produce_demogorgon");
        System.out.println("produce_demogorgon() method invoked");
        Properties producerProps = new Properties();
        producerProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        producerProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        producerProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        Random random = new Random();

        Producer<String, String> producer = new KafkaProducer<>(producerProps);
        try {
            int i = 0;
            while(true) {
                producer.send(new ProducerRecord<>(DEMOGORGON_TOPIC, Integer.toString(i), "Sending a message to Demogorgon! " + i));
                i++;
                int randomInt = random.nextInt(801)+400;
                // Sleep to simulate processing time (optional)
                try {
                    Thread.sleep(randomInt);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        } finally {
            producer.close();
        }
    }

    @Trace(dispatcher = true)
    public static void consume() {
        NewRelic.setTransactionName(null, "kafkaClient/consume");
        System.out.println("consume() method invoked");
        Properties consumerProps = new Properties();
        consumerProps.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        consumerProps.put(ConsumerConfig.GROUP_ID_CONFIG, "demogorgonConsumer");
        consumerProps.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        consumerProps.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        consumerProps.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

        Consumer<String, String> consumer = new KafkaConsumer<>(consumerProps);
        consumer.subscribe(Collections.singletonList(DEMOGORGON_TOPIC));

        try {
            while (true) {
                ConsumerRecords<String, String> records = consumer.poll(100);
                records.forEach(record -> System.out.printf("Consumed message: %s%n", record.value()));
                // Sleep to simulate processing time (optional)
                try {
                    Thread.sleep(100);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        } finally {
            consumer.close();
        }
    }
}