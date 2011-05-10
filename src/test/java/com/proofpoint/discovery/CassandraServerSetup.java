package com.proofpoint.discovery;

import com.google.common.io.Files;
import com.proofpoint.node.NodeInfo;
import org.apache.cassandra.config.ConfigurationException;
import org.apache.thrift.transport.TTransportException;
import org.testng.annotations.AfterClass;
import org.testng.annotations.AfterSuite;
import org.testng.annotations.BeforeSuite;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

public class CassandraServerSetup
{
    private final static AtomicBoolean initialized = new AtomicBoolean();
    private final static AtomicBoolean shutdown = new AtomicBoolean();

    private static File tempDir;
    private static EmbeddedCassandraServer server;
    private static int rpcPort;

    public static void tryInitialize()
            throws IOException, TTransportException, ConfigurationException, InterruptedException
    {
        if (initialized.compareAndSet(false, true)) {
            rpcPort = findUnusedPort();
            tempDir = Files.createTempDir();
            CassandraServerConfig config = new CassandraServerConfig()
                    .setSeeds("localhost")
                    .setStoragePort(findUnusedPort())
                    .setRpcPort(rpcPort)
                    .setClusterName("discovery")
                    .setDirectory(tempDir);

            NodeInfo nodeInfo = new NodeInfo("testing");

            server = new EmbeddedCassandraServer(config, nodeInfo);
            server.start();
        }
    }

    public static void tryShutdown()
            throws IOException
    {
        if (shutdown.compareAndSet(false, true)) {
            server.stop();
            try {
                Files.deleteRecursively(tempDir);
            }
            catch (IOException e) {
                // ignore
            }
        }
    }

    public static CassandraServerInfo getServerInfo()
    {
        return new CassandraServerInfo(rpcPort);
    }

    private static int findUnusedPort()
            throws IOException
    {
        ServerSocket socket = new ServerSocket();
        try {
            socket.bind(new InetSocketAddress(0));
            return socket.getLocalPort();
        }
        finally {
            socket.close();
        }
    }
}