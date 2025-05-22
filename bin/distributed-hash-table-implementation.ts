type HashFunction = (key: string) => number;

interface Node {
  id: string;
  address: string;
  isAlive: boolean;
  data: Map<string, string>;
  replicas: Set<string>;
  getData: () => Map<string, string>;
  storeData: (key: string, value: string) => void;
  deleteData: (key: string) => void;
  replicateData: (key: string, value: string) => void;
  receiveReplication: (key: string, value: string) => void;
  heartbeat: () => boolean;
}

class DistributedHashTable {
  private nodes: Map<string, Node>;
  private hashFunction: HashFunction;
  private replicationFactor: number;
  private ring: string[];
  private sortedNodes: Node[];

  constructor(nodes: Node[], hashFunction: HashFunction, replicationFactor: number = 3) {
    this.nodes = new Map();
    nodes.forEach(node => this.nodes.set(node.id, node));
    this.hashFunction = hashFunction;
    this.replicationFactor = replicationFactor;
    this.ring = [];
    this.sortedNodes = [];
    this.buildRing();
  }

  private buildRing(): void {
    this.ring = Array.from(this.nodes.values()).map(node => node.id);
    this.ring.sort((a, b) => this.hashFunction(a) - this.hashFunction(b));
    this.sortedNodes = this.ring.map(id => this.nodes.get(id)!);
  }

  private getSuccessorNodes(key: string): Node[] {
    const hash = this.hashFunction(key);
    const index = this.ring.findIndex(id => this.hashFunction(id) >= hash);
    const primaryIndex = index === -1 ? 0 : index;
    const result: Node[] = [];
    for (let i = 0; i < this.replicationFactor; i++) {
      const nodeIndex = (primaryIndex + i) % this.ring.length;
      result.push(this.nodes.get(this.ring[nodeIndex])!);
    }
    return result;
  }

  public put(key: string, value: string): void {
    const nodes = this.getSuccessorNodes(key);
    nodes.forEach(node => {
      node.storeData(key, value);
      node.replicateData(key, value);
    });
  }

  public get(key: string): string | null {
    const nodes = this.getSuccessorNodes(key);
    for (const node of nodes) {
      const data = node.getData();
      if (data.has(key)) {
        return data.get(key)!;
      }
    }
    return null;
  }

  public delete(key: string): void {
    const nodes = this.getSuccessorNodes(key);
    nodes.forEach(node => {
      node.deleteData(key);
    });
  }

  public addNode(node: Node): void {
    this.nodes.set(node.id, node);
    this.buildRing();
  }

  public removeNode(nodeId: string): void {
    this.nodes.delete(nodeId);
    this.buildRing();
  }

  public performHeartbeat(): void {
    this.nodes.forEach(node => {
      node.isAlive = node.heartbeat();
    });
  }

  public recoverNode(node: Node): void {
    this.addNode(node);
    this.rebalanceData();
  }

  private rebalanceData(): void {
    this.nodes.forEach(node => {
      node.getData().forEach((value, key) => {
        const responsibleNodes = this.getSuccessorNodes(key);
        if (!responsibleNodes.includes(node)) {
          node.deleteData(key);
        }
      });
    });
    this.nodes.forEach(node => {
      node.getData().forEach((value, key) => {
        const responsibleNodes = this.getSuccessorNodes(key);
        if (responsibleNodes.includes(node)) {
          responsibleNodes.forEach(rNode => {
            if (!rNode.getData().has(key)) {
              rNode.storeData(key, value);
            }
          });
        }
      });
    });
  }
}

class DHTNode implements Node {
  id: string;
  address: string;
  isAlive: boolean;
  data: Map<string, string>;
  replicas: Set<string>;

  constructor(id: string, address: string) {
    this.id = id;
    this.address = address;
    this.isAlive = true;
    this.data = new Map();
    this.replicas = new Set();
  }

  getData(): Map<string, string> {
    return this.data;
  }

  storeData(key: string, value: string): void {
    this.data.set(key, value);
  }

  deleteData(key: string): void {
    this.data.delete(key);
  }

  replicateData(key: string, value: string): void {
    this.replicas.forEach(replicaId => {
      // Placeholder for network replication call
    });
  }

  receiveReplication(key: string, value: string): void {
    this.data.set(key, value);
  }

  heartbeat(): boolean {
    return this.isAlive;
  }
}

const simpleHash: HashFunction = (key: string) => {
  let hash = 0;
  for (let i = 0; i < key.length; i++) {
    hash = (hash << 5) - hash + key.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
};

const nodeA = new DHTNode('nodeA', '192.168.1.1');
const nodeB = new DHTNode('nodeB', '192.168.1.2');
const nodeC = new DHTNode('nodeC', '192.168.1.3');
const dht = new DistributedHashTable([nodeA, nodeB, nodeC], simpleHash, 2);

dht.put("key1", "value1");
dht.put("key2", "value2");
console.log(dht.get("key1"));
console.log(dht.get("key2"));

dht.delete("key1");
console.log(dht.get("key1"));
dht.performHeartbeat();

const nodeD = new DHTNode('nodeD', '192.168.1.4');
dht.addNode(nodeD);
dht.recoverNode(nodeD);