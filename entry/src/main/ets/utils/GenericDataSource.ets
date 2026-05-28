export class GenericDataSource<T> implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private dataArray: T[] = [];

  constructor(data: T[]) {
    this.dataArray = data;
  }

  totalCount(): number {
    return this.dataArray.length;
  }

  getData(index: number): T {
    return this.dataArray[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  /** Full data replacement — triggers complete reload */
  updateData(newData: T[]): void {
    this.dataArray = newData;
    this.notifyDataReload();
  }

  /** Append a single item */
  addData(index: number, item: T): void {
    this.dataArray.splice(index, 0, item);
    this.notifyDataAdd(index);
  }

  /** Remove a single item */
  deleteData(index: number): void {
    this.dataArray.splice(index, 1);
    this.notifyDataDelete(index);
  }

  /** Move item (for drag-to-reorder) */
  moveData(from: number, to: number): void {
    const item = this.dataArray.splice(from, 1)[0];
    this.dataArray.splice(to, 0, item);
    this.notifyDataMove(from, to);
  }

  /** 按条件查找索引，未找到返回 -1 */
  findIndex(predicate: (item: T) => boolean): number {
    return this.dataArray.findIndex(predicate);
  }

  /** 精准更新单项 —— 仅通知 LazyForEach 刷新该位置，不触发全量重建 */
  updateItem(index: number, item: T): void {
    this.dataArray[index] = item;
    this.notifyDataChange(index);
  }

  // --- Internal notification methods ---
  private notifyDataReload(): void {
    this.listeners.forEach((l: DataChangeListener): void => {
      l.onDataReloaded();
    });
  }

  private notifyDataAdd(index: number): void {
    this.listeners.forEach((l: DataChangeListener): void => {
      l.onDataAdd(index);
    });
  }

  private notifyDataDelete(index: number): void {
    this.listeners.forEach((l: DataChangeListener): void => {
      l.onDataDelete(index);
    });
  }

  private notifyDataChange(index: number): void {
    this.listeners.forEach((l: DataChangeListener): void => {
      l.onDataChange(index);
    });
  }

  private notifyDataMove(from: number, to: number): void {
    this.listeners.forEach((l: DataChangeListener): void => {
      l.onDataMove(from, to);
    });
  }
}
