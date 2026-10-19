import { ConflictException, Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Timestamp } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import type { Auth } from 'firebase-admin/auth';
import nodemailer from 'nodemailer';
import PDFDocument from 'pdfkit';
import {
  FIREBASE_AUTH,
  FIREBASE_FIRESTORE,
} from '../firebase/firebase.providers.js';
import { OrdersRepository } from '../orders/orders.repository.js';

interface Receipt {
  orderId: string;
  number: string;
  userId: string;
  email: string | null;
  customer: string;
  storeName: string;
  issuedAt: string;
  items: {
    name: string;
    size: string;
    quantity: number;
    unitPriceCents: number;
  }[];
  subtotalCents: number;
  deliveryFeeCents: number;
  totalCents: number;
  status: string;
}
const money = (value: number) => `S/ ${(value / 100).toFixed(2)}`;
const htmlEscapes: Record<string, string> = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
};
const escape = (value: string) =>
  value.replace(/[&<>"']/g, (c) => htmlEscapes[c]!);

@Injectable()
export class ReceiptsService {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
    @Inject(FIREBASE_AUTH) private readonly auth: Auth,
    @Inject(ConfigService) private readonly config: ConfigService,
    @Inject(OrdersRepository) private readonly orders: OrdersRepository,
  ) {}

  private async materialize(id: string, uid?: string): Promise<Receipt> {
    const order = await this.orders.find(id, uid);
    if (!order.isSimulation || order.paymentStatus !== 'SIMULADO')
      throw new ConflictException('La boleta se genera al registrar un pago.');
    const ref = this.firestore.collection('order_receipts').doc(id);
    const existing = await ref.get();
    if (existing.exists) return existing.data() as Receipt;
    // Address comes from Firebase Authentication, never from a request parameter.
    const customer = await this.auth.getUser(order.userId);
    const settings = await this.firestore
      .collection('store_settings')
      .doc('main')
      .get();
    const receipt: Receipt = {
      orderId: id,
      number: `SIM-${id.toUpperCase()}`,
      userId: order.userId,
      email: customer.email ?? null,
      customer: order.delivery.recipientName,
      storeName: settings.data()?.storeName ?? 'SneakerStore',
      issuedAt: order.simulationCompletedAt ?? new Date().toISOString(),
      items: order.items,
      subtotalCents: order.subtotalCents,
      deliveryFeeCents: order.deliveryFeeCents,
      totalCents: order.totalCents,
      status: 'READY',
    };
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (snapshot.exists) return snapshot.data() as Receipt;
      transaction.create(ref, receipt);
      return receipt;
    });
  }

  async get(id: string, uid?: string) {
    const receipt = await this.materialize(id, uid);
    return {
      number: receipt.number,
      orderId: id,
      email: receipt.email,
      issuedAt: receipt.issuedAt,
      customer: receipt.customer,
      storeName: receipt.storeName,
      items: receipt.items,
      subtotalCents: receipt.subtotalCents,
      deliveryFeeCents: receipt.deliveryFeeCents,
      totalCents: receipt.totalCents,
      status: receipt.status,
      notice: 'BOLETA DE PAGO REALIZADO · SIN VALOR TRIBUTARIO',
    };
  }

  async pdf(id: string, uid?: string) {
    return this.renderPdf(await this.materialize(id, uid));
  }

  private renderPdf(receipt: Receipt): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ size: 'A4', margin: 48 });
      const chunks: Buffer[] = [];
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);
      doc.fontSize(23).fillColor('#111111').text(receipt.storeName);
      doc.moveDown(0.4).fontSize(14).fillColor('#AB3500').text('BOLETA');
      doc.fontSize(10).text('SIN COBRO REAL - SIN VALOR TRIBUTARIO');
      doc
        .moveDown()
        .fillColor('#111111')
        .fontSize(9)
        .text(`Número: ${receipt.number}`);
      doc.text(`Emitida: ${receipt.issuedAt}`);
      doc.text(`Cliente: ${receipt.customer}`);
      doc.text(`Correo registrado: ${receipt.email ?? 'No disponible'}`);
      doc.moveDown(1.5).fontSize(12).text('Detalle del pedido');
      for (const item of receipt.items) {
        doc.moveDown(0.7).fontSize(10).text(`${item.name} - EU ${item.size}`);
        doc
          .fontSize(9)
          .text(
            `${item.quantity} x ${money(item.unitPriceCents)} = ${money(item.quantity * item.unitPriceCents)}`,
          );
      }
      doc
        .moveDown(1.5)
        .fontSize(10)
        .text(`Subtotal: ${money(receipt.subtotalCents)}`);
      doc.text(`Envío: ${money(receipt.deliveryFeeCents)}`);
      doc
        .moveDown(0.5)
        .fontSize(15)
        .text(`TOTAL: ${money(receipt.totalCents)}`);
      doc
        .moveDown(1)
        .fontSize(10)
        .fillColor('#AB3500')
        .text('Importe realmente cobrado: S/ 0.00');
      doc
        .moveDown()
        .fillColor('#555555')
        .fontSize(9)
        .text(
          'Este documento corresponde a una demostración de compra. No acredita una transferencia, no es una factura ni una boleta fiscal.',
        );
      doc.end();
    });
  }

  private async status(id: string, status: string) {
    const batch = this.firestore.batch();
    batch.update(this.firestore.collection('order_receipts').doc(id), {
      status,
      updatedAt: Timestamp.now(),
    });
    batch.update(this.firestore.collection('orders').doc(id), {
      receiptStatus: status,
    });
    await batch.commit();
  }

  async deliver(id: string, uid: string) {
    // Failure of email delivery must never roll back an already completed demo order.
    try {
      const receipt = await this.materialize(id, uid);
      if (receipt.status === 'SENT') return { status: 'SENT' };
      if (!receipt.email) {
        await this.status(id, 'NO_EMAIL');
        return { status: 'NO_EMAIL' };
      }
      const host = this.config.get<string>('SMTP_HOST')?.trim();
      const user = this.config.get<string>('SMTP_USER')?.trim();
      const pass = this.config.get<string>('SMTP_PASS');
      const from = this.config.get<string>('SMTP_FROM')?.trim();
      const port = Number(this.config.get('SMTP_PORT') ?? 587);
      if (
        !host ||
        !user ||
        !pass ||
        !from ||
        !Number.isInteger(port) ||
        port < 1 ||
        port > 65535
      ) {
        await this.status(id, 'NOT_CONFIGURED');
        return { status: 'NOT_CONFIGURED' };
      }
      const ref = this.firestore.collection('order_receipts').doc(id);
      const acquired = await this.firestore.runTransaction(
        async (transaction) => {
          const snapshot = await transaction.get(ref);
          const data = snapshot.data()!;
          if (data.status === 'SENT') return false;
          if (
            data.lastAttemptAt instanceof Timestamp &&
            data.lastAttemptAt.toMillis() > Date.now() - 120000
          )
            return false;
          transaction.update(ref, {
            status: 'SENDING',
            lastAttemptAt: Timestamp.now(),
          });
          return true;
        },
      );
      if (!acquired)
        return { status: (await ref.get()).data()!.status as string };
      const pdf = await this.renderPdf(receipt);
      const transport = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        requireTLS: port !== 465,
        auth: { user, pass },
        connectionTimeout: 10000,
        greetingTimeout: 10000,
        socketTimeout: 15000,
        logger: false,
        debug: false,
        disableFileAccess: true,
        disableUrlAccess: true,
      });
      const result = await transport.sendMail({
        from,
        to: receipt.email,
        subject: `SneakerStore · Boleta ${receipt.number.slice(0, 16)}`,
        text: `Hola ${receipt.customer}.\nAdjuntamos tu boleta.\nPedido: ${id}\nTotal: ${money(receipt.totalCents)}.\nImporte cobrado: S/ 0.00.\nSIN VALOR TRIBUTARIO.`,
        html: `<h1>${escape(receipt.storeName)}</h1><h2>Boleta</h2><p>Hola ${escape(receipt.customer)}.</p><p>Adjuntamos tu comprobante del pedido ${escape(id)}.</p><p>Total: <strong>${money(receipt.totalCents)}</strong>.</p><p>Importe cobrado: <strong>S/ 0.00</strong>.</p><p>Sin cobro real. Sin valor tributario.</p>`,
        attachments: [
          {
            filename: `Boleta-${id.slice(0, 12)}.pdf`,
            content: pdf,
            contentType: 'application/pdf',
          },
        ],
      });
      if (result.accepted.length === 0)
        throw new Error('SMTP did not accept the recipient');
      await this.status(id, 'SENT');
      return { status: 'SENT' };
    } catch {
      // Never forward SMTP errors or credentials to the client or logs.
      try {
        const ref = this.firestore.collection('order_receipts').doc(id);
        if ((await ref.get()).exists) await this.status(id, 'FAILED');
      } catch {
        /* Delivery state can be reloaded later. */
      }
      return { status: 'FAILED' };
    }
  }
}
