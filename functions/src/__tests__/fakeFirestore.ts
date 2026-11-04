import { FieldValue, Firestore } from "firebase-admin/firestore";

/**
 * In-memory stand-in for the parts of Firestore the functions use. Transactions
 * copy Firestore's optimistic behaviour: if anything read has changed by commit
 * time, the transaction reruns. That makes concurrent-claim tests meaningful.
 */
type Data = Record<string, any>;

const tick = () => new Promise((resolve) => setImmediate(resolve));

class FakeSnap {
  constructor(public ref: FakeDocRef, private value: Data | undefined) {}
  get exists() {
    return this.value !== undefined;
  }
  get id() {
    return this.ref.id;
  }
  data() {
    return this.value === undefined ? undefined : { ...this.value };
  }
}

class FakeDocRef {
  constructor(public store: FakeFirestore, public path: string, public id: string) {}
  async get() {
    await tick();
    return new FakeSnap(this, this.store.docs.get(this.path)?.data);
  }
  async create(data: Data) {
    await tick();
    if (this.store.docs.has(this.path)) throw Object.assign(new Error("exists"), { code: 6 });
    this.store.write(this.path, { ...data });
  }
  async set(data: Data) {
    await tick();
    this.store.write(this.path, { ...data });
  }
}

interface Filter {
  field: string;
  op: "==" | ">";
  value: unknown;
}

class FakeQuery {
  constructor(public store: FakeFirestore, public name: string, public filters: Filter[] = [], public max = Infinity) {}
  where(field: string, op: "==" | ">", value: unknown) {
    return new FakeQuery(this.store, this.name, [...this.filters, { field, op, value }], this.max);
  }
  limit(max: number) {
    return new FakeQuery(this.store, this.name, this.filters, max);
  }
  run() {
    const docs: FakeSnap[] = [];
    for (const [path, entry] of this.store.docs) {
      if (!path.startsWith(`${this.name}/`)) continue;
      const match = this.filters.every(({ field, op, value }) =>
        op === "==" ? entry.data[field] === value : entry.data[field] > (value as number)
      );
      if (match) docs.push(new FakeSnap(new FakeDocRef(this.store, path, path.split("/")[1]), entry.data));
    }
    const limited = docs.slice(0, this.max);
    return { docs: limited, empty: limited.length === 0, size: limited.length };
  }
}

class FakeCollection extends FakeQuery {
  doc(id?: string) {
    const docId = id ?? `auto${++this.store.autoId}`;
    return new FakeDocRef(this.store, `${this.name}/${docId}`, docId);
  }
}

export class FakeFirestore {
  docs = new Map<string, { data: Data; version: number }>();
  autoId = 0;
  private collectionVersions = new Map<string, number>();
  transactionRuns = 0;

  collection(name: string) {
    return new FakeCollection(this, name);
  }

  write(path: string, data: Data | undefined) {
    const version = (this.docs.get(path)?.version ?? 0) + 1;
    if (data === undefined) this.docs.delete(path);
    else this.docs.set(path, { data, version });
    const name = path.split("/")[0];
    this.collectionVersions.set(name, (this.collectionVersions.get(name) ?? 0) + 1);
  }

  /** Test helper: read a document's stored data directly. */
  read(path: string): Data | undefined {
    return this.docs.get(path)?.data;
  }

  seed(path: string, data: Data) {
    this.write(path, data);
  }

  async runTransaction<T>(fn: (tx: any) => Promise<T>): Promise<T> {
    for (let attempt = 0; attempt < 20; attempt++) {
      this.transactionRuns++;
      const reads = new Map<string, number>();
      const collections = new Map<string, number>();
      const writes: Array<() => void> = [];
      const self = this;
      const pathOf = (ref: FakeDocRef) => ref.path;

      const tx = {
        async get(target: FakeDocRef | FakeQuery) {
          await tick();
          if (writes.length > 0) throw new Error("Firestore requires reads before writes");
          if (target instanceof FakeDocRef) {
            const entry = self.docs.get(pathOf(target));
            reads.set(pathOf(target), entry?.version ?? 0);
            return new FakeSnap(target, entry?.data);
          }
          collections.set(target.name, self.collectionVersions.get(target.name) ?? 0);
          return target.run();
        },
        set(ref: FakeDocRef, data: Data, options?: { merge?: boolean }) {
          writes.push(() => {
            const base = options?.merge ? self.docs.get(ref.path)?.data ?? {} : {};
            self.write(ref.path, applyValues(base, data));
          });
        },
        create(ref: FakeDocRef, data: Data) {
          writes.push(() => {
            if (self.docs.has(ref.path)) throw Object.assign(new Error("exists"), { code: 6 });
            self.write(ref.path, applyValues({}, data));
          });
        },
        update(ref: FakeDocRef, data: Data) {
          writes.push(() => {
            const base = self.docs.get(ref.path)?.data;
            if (!base) throw Object.assign(new Error("no document to update"), { code: 5 });
            self.write(ref.path, applyValues(base, data));
          });
        },
        delete(ref: FakeDocRef) {
          writes.push(() => self.write(ref.path, undefined));
        },
      };

      const result = await fn(tx);
      await tick();

      // Commit runs synchronously, so it is atomic relative to other transactions.
      const stale =
        [...reads].some(([path, version]) => (self.docs.get(path)?.version ?? 0) !== version) ||
        [...collections].some(([name, version]) => (self.collectionVersions.get(name) ?? 0) !== version);
      if (stale) continue;

      writes.forEach((apply) => apply());
      return result;
    }
    throw new Error("Transaction contention: too many retries");
  }

  asFirestore(): Firestore {
    return this as unknown as Firestore;
  }
}

function applyValues(base: Data, changes: Data): Data {
  const next = { ...base };
  for (const [key, value] of Object.entries(changes)) {
    if (value instanceof FieldValue && value.isEqual(FieldValue.delete())) delete next[key];
    else next[key] = value;
  }
  return next;
}
